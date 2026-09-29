class TasksController < ApplicationController
  before_action :load_project, only: [:index, :create]
  before_action :load_task,    only: [:show, :edit, :update, :destroy, :move, :move_project, :quick_update]

  def index
    @tab = "tasks"
    @tasks = @project.tasks.kept.includes(:assignee, :board_column, :labels)
    @tasks = @tasks.where.not(status: Task.statuses[:cancelled]) unless params[:show_cancelled] == "1"
    @tasks = @tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    @tasks = @tasks.where(priority: params[:priority])       if params[:priority].present?
    @tasks = @tasks.where(board_column_id: params[:column_id]) if params[:column_id].present?
    @tasks = @tasks.search_like(:title, :code, term: params[:q]) if params[:q].present?

    @tasks = case params[:sort]
             when "due"      then @tasks.order(Arel.sql("due_date NULLS LAST"))
             when "priority" then @tasks.order(priority: :desc)
             when "created"  then @tasks.order(created_at: :desc)
             else @tasks.order(:board_column_id, :position)
             end

    @pagy  = Pagination.new(@tasks, page: params[:page])
    @tasks = @pagy.records
    @movable_projects = movable_projects_for(@project)
  end

  def show
    @movable_projects = movable_projects_for(@project) if @task.movable_to_other_project?
  end

  def new
    @task = Task.new(priority: :medium, project_id: params[:project_id])
    @projects = Project.active.visible_to(current_user).order(:name)
  end

  def create
    @task = @project.tasks.new(task_params)
    @task.reporter = current_user

    if @task.save
      apply_labels
      log_activity("created", trackable: @task, project: @project, summary: "đã tạo công việc #{@task.code}")
      Notifications::Dispatch.task_assigned(@task, actor: current_user) if @task.assignee_id
      if params[:board_composer].present?
        # Thêm ngay trên bảng Kanban: chỉ chèn thẻ vào đúng cột, không nạp lại
        # trang — người dùng giữ nguyên chỗ cuộn và gõ tiếp việc kế tiếp.
        render turbo_stream: turbo_stream.append("column_tasks_#{@task.board_column_id}",
                                                 partial: "tasks/card", locals: { task: @task })
      elsif turbo_frame_request?
        # Mở từ trong một tab của dự án thì quay lại đúng tab đó; mở từ thanh
        # trên (không có return_to) thì vào thẳng công việc vừa tạo.
        close_modal_and_go(return_to_path(task_path(@task)), notice: "Đã tạo công việc #{@task.code}.")
      else
        redirect_back fallback_location: project_board_path(@project), notice: "Đã tạo #{@task.code}."
      end
    elsif params[:board_composer].present?
      flash.now[:alert] = @task.errors.full_messages.to_sentence
      render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash"),
             status: :unprocessable_entity
    else
      redirect_back fallback_location: project_board_path(@project),
                    alert: @task.errors.full_messages.to_sentence
    end
  end

  # Không có màn sửa riêng: mọi thứ sửa ngay trong chi tiết công việc.
  def edit = redirect_to task_path(@task)

  def update
    previous = { assignee_id: @task.assignee_id, board_column_id: @task.board_column_id, status: @task.status }

    if @task.update(task_params)
      apply_labels
      log_activity("updated", trackable: @task, project: @task.project, summary: "đã cập nhật #{@task.code}")
      notify_changes(previous)
      # Vẽ lại chi tiết (panel hoặc trang riêng) VÀ hàng/thẻ của việc đó ở màn
      # phía sau. Trước đây chỉ nạp lại panel nên danh sách sau lưng vẫn hiện
      # trạng thái cũ cho tới khi người dùng tự tải lại trang.
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Đã lưu công việc #{@task.code}."
          render turbo_stream: task_sync_streams(moved_column: previous[:board_column_id] != @task.board_column_id)
        end
        format.html { redirect_back fallback_location: task_path(@task), notice: "Đã lưu công việc #{@task.code}." }
      end
    else
      message = @task.errors.full_messages.to_sentence
      respond_to do |format|
        # Trong panel mà redirect thì Turbo nạp trang đích vào chính cái panel.
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash"), status: :unprocessable_entity
        end
        format.html { redirect_back fallback_location: task_path(@task), alert: message }
      end
    end
  end

  # Kéo–thả Kanban: PATCH /cong-viec/:code/move
  def move
    column = @task.project.board_columns.find(params[:board_column_id])
    previous_column = @task.board_column

    @task.move_to!(column, prev_position: params[:prev_position], next_position: params[:next_position])
    if previous_column&.id != column.id
      log_activity("moved", trackable: @task, project: @task.project,
                   summary: "đã chuyển #{@task.code} sang cột #{column.name}",
                   changes_payload: { from: previous_column&.name, to: column.name })
      Notifications::Dispatch.task_status_changed(@task, actor: current_user)
    end

    respond_to do |format|
      format.json { render json: { ok: true, status: @task.status, progress: @task.project.progress } }
      format.turbo_stream { head :ok }
      format.html { head :ok }
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: { message: e.record.errors.full_messages.to_sentence } }, status: :unprocessable_entity
  end

  # Chuyển công việc sang dự án khác (chỉ việc chưa hoàn thành).
  #
  # Trả lời bằng turbo_stream để người dùng ở nguyên màn đang đứng: thẻ/hàng của
  # việc vừa chuyển biến mất, panel và trang chi tiết vẽ lại theo dự án mới, và
  # có dòng báo kết quả. Chỉ khi không dùng được turbo_stream mới điều hướng.
  def move_project
    target = visible_projects.find_by(code: params[:project_code])
    return move_failed("Không tìm thấy dự án đó trong phạm vi của bạn.") if target.nil?

    result = Tasks::MoveToProject.new(@task, target).call
    return move_failed(result.error) unless result.ok?

    log_activity("moved", trackable: @task, project: target,
                 summary: "đã chuyển #{result.previous_code} từ #{result.previous_project.code} sang #{target.code} (#{@task.code})",
                 changes_payload: { from: result.previous_project.code, to: target.code,
                                    from_code: result.previous_code, to_code: @task.code })
    Notifications::Dispatch.task_moved_project(@task, from: result.previous_project,
                                               previous_assignee: result.dropped_assignee, actor: current_user)

    # Vẽ lại chi tiết theo dự án MỚI: cột, thành viên và nhãn trong màn chi tiết
    # đều lấy từ @project.
    @project = @task.project
    @movable_projects = movable_projects_for(@project)
    notice = move_notice(result, target)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: move_streams(result.previous_code)
      end
      # Mã việc đổi theo dự án mới nên đường dẫn cũ không còn — đi tới mã mới,
      # trừ khi nơi gửi đã nói rõ muốn quay về đâu.
      format.html { redirect_to return_to_path(task_path(@task)), notice: notice }
    end
  end

  # Sửa nhanh một trường (chip đổi trạng thái ở đầu chi tiết, sửa nhanh từ panel).
  # Ghi nhật ký và báo cho người liên quan y như lưu bằng form đầy đủ — đổi cột
  # bằng chip hay bằng ô chọn thì với người đọc nhật ký vẫn là một việc.
  def quick_update
    previous = { assignee_id: @task.assignee_id, board_column_id: @task.board_column_id, status: @task.status }

    if @task.update(task_params)
      log_activity("updated", trackable: @task, project: @task.project, summary: "đã cập nhật #{@task.code}")
      notify_changes(previous)

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = quick_update_notice(previous)
          render turbo_stream: task_sync_streams(moved_column: previous[:board_column_id] != @task.board_column_id)
        end
        format.json { render json: { ok: true } }
        format.html { redirect_back fallback_location: task_path(@task) }
      end
    else
      message = @task.errors.full_messages.to_sentence
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash"), status: :unprocessable_entity
        end
        format.json { render json: { error: { message: message } }, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: task_path(@task), alert: message }
      end
    end
  end

  def bulk_update
    tasks = Task.kept.where(code: Array(params[:codes]))
                     .where(project_id: visible_project_ids)
    attrs = {}
    attrs[:assignee_id]     = params[:assignee_id].presence     if params.key?(:assignee_id)
    attrs[:board_column_id] = params[:board_column_id].presence if params[:board_column_id].present?
    attrs[:priority]        = params[:priority]                 if params[:priority].present?

    updated = tasks.select { |t| t.update(attrs) }
    redirect_back fallback_location: root_path, notice: "Đã cập nhật #{updated.size} công việc."
  end

  def destroy
    authorize_owner_or_admin!(@task.reporter_id)
    @task.discard
    log_activity("deleted", trackable: @task, project: @task.project, summary: "đã xoá #{@task.code}")
    flash[:notice] = "Đã xoá công việc #{@task.code}."
    if turbo_frame_request?
      # Đóng panel rồi điều hướng cả trang — nếu redirect thường, trang bảng
      # sẽ bị nạp vào bên trong panel.
      render turbo_stream: [turbo_stream.update("modal", ""),
                            turbo_stream.action(:redirect, project_board_path(@task.project))]
    else
      redirect_to project_board_path(@task.project)
    end
  end

  private

  def load_project
    @project = Project.kept.includes(:members, :board_columns)
                      .find_by!(code: params[:project_code] || params.dig(:task, :project_code))
    authorize_project!(@project)
  end

  def load_task
    @task = Task.kept.includes(:project, :assignee, :labels, :subtasks, :comments).find_by!(code: params[:code])
    @project = @task.project
    authorize_project!(@project)
  end

  # Dự án chuyển được: còn hoạt động và trong phạm vi người xem, kèm cả dự án
  # hiện tại để ô chọn cho thấy việc đang nằm ở đâu.
  def movable_projects_for(project)
    visible_projects.where(archived_at: nil).or(visible_projects.where(id: project.id)).order(:name)
  end

  def task_params
    # Không nhận :project_id ở đây: đổi dự án còn phải đổi cột, nhãn và mã việc,
    # nên phải đi qua move_project chứ không lọt qua form sửa thường được.
    params.require(:task).permit(:title, :description, :priority, :assignee_id, :board_column_id,
                                 :start_date, :due_date, :estimated_hours, :status, files: [])
  end

  def apply_labels
    return unless params[:task].key?(:label_ids)
    ids = Array(params[:task][:label_ids]).reject(&:blank?).map(&:to_i)
    @task.task_labels.where.not(label_id: ids).destroy_all
    (ids - @task.task_labels.pluck(:label_id)).each { |lid| @task.task_labels.create(label_id: lid) }
  end

  def notify_changes(previous)
    Notifications::Dispatch.task_assigned(@task, actor: current_user) if @task.assignee_id && previous[:assignee_id] != @task.assignee_id
    Notifications::Dispatch.task_status_changed(@task, actor: current_user) if previous[:status] != @task.status
  end

  # Vẽ lại việc vừa sửa ở mọi chỗ đang hiển thị nó: panel (hoặc trang chi tiết),
  # thẻ trên Kanban, hàng trong danh sách dạng dòng và hàng trong bảng.
  # turbo_stream bỏ qua đích không có trên trang nên gửi thừa là vô hại — nhờ vậy
  # controller không phải đoán người dùng đang đứng ở màn nào.
  def task_sync_streams(moved_column: false)
    # Trên Kanban, đổi cột thì thẻ phải SANG cột mới chứ không phải vẽ lại tại
    # chỗ cũ. Cột không đổi thì thay tại chỗ để giữ nguyên thứ tự trong cột.
    card = if moved_column
             [turbo_stream.remove("task_card_#{@task.code}"),
              turbo_stream.append("column_tasks_#{@task.board_column_id}",
                                  partial: "tasks/card", locals: { task: @task })]
           else
             [turbo_stream.replace("task_card_#{@task.code}", partial: "tasks/card", locals: { task: @task })]
           end

    streams = [turbo_stream.replace("flash", partial: "layouts/flash"),
               *card,
               turbo_stream.replace("task_trow_#{@task.code}", partial: "tasks/table_row",
                                    locals: { task: @task, movable: true }),
               turbo_stream.replace("task_row_#{@task.code}", partial: "shared/task_row",
                                    locals: { task: @task, show_project: true, show_assignee: false }),
               turbo_stream.replace("task_row_a_#{@task.code}", partial: "shared/task_row",
                                    locals: { task: @task, show_project: true, show_assignee: true })]

    streams << if turbo_frame_request?
                 turbo_stream.replace("modal", partial: "tasks/modal_frame")
               else
                 turbo_stream.replace("task_page", partial: "tasks/page")
               end
    streams
  end

  # Nói rõ vừa đổi gì, vì chip đổi trạng thái nằm xa dải thông báo.
  def quick_update_notice(previous)
    if previous[:board_column_id] != @task.board_column_id
      "Đã chuyển #{@task.code} sang #{@task.board_column&.name}."
    else
      "Đã lưu công việc #{@task.code}."
    end
  end

  # Gỡ thẻ/hàng của mã cũ ở mọi nơi có thể đang hiển thị nó — turbo_stream bỏ
  # qua đích không tồn tại nên gửi thừa cũng vô hại, mà panel mở từ bảng Kanban
  # thì vừa vẽ lại panel vừa dọn cái thẻ phía sau.
  def move_streams(previous_code)
    streams = [turbo_stream.replace("flash", partial: "layouts/flash"),
               turbo_stream.remove("task_card_#{previous_code}"),
               turbo_stream.remove("task_trow_#{previous_code}"),
               turbo_stream.remove("task_row_#{previous_code}"),
               turbo_stream.remove("task_row_a_#{previous_code}")]

    if turbo_frame_request?
      streams << turbo_stream.replace("modal", partial: "tasks/modal_frame")
    elsif params[:context] == "detail"
      streams << turbo_stream.replace("task_page", partial: "tasks/page")
      streams << turbo_stream.update("page_title", "Công việc #{@task.code}")
      streams << turbo_stream.action(:replace_url, task_path(@task))
      streams << turbo_stream.action(:set_title, "Công việc #{@task.code} · #{current_workspace.name}")
    end
    streams
  end

  def move_failed(message)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = message
        render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash")
      end
      format.html { redirect_back fallback_location: task_path(@task), alert: message }
    end
  end

  # Nói thẳng những gì bị gỡ bỏ — người thực hiện và nhãn không theo việc sang
  # dự án mới được, mà nhìn màn hình thì không thấy chúng biến mất.
  def move_notice(result, target)
    parts = ["Đã chuyển #{result.previous_code} sang #{target.code} · #{target.name}, mã mới là #{@task.code}."]
    parts << "Bỏ người thực hiện #{result.dropped_assignee.display_name} vì chưa là thành viên dự án mới." if result.dropped_assignee
    parts << "Gỡ #{result.dropped_labels.size} nhãn của dự án cũ." if result.dropped_labels.any?
    parts.join(" ")
  end

  def authorize_owner_or_admin!(creator_id)
    return if current_user.role_admin? || creator_id == current_user.id
    raise Pundit::NotAuthorizedError
  end
end
