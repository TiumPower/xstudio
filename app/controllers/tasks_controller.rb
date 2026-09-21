class TasksController < ApplicationController
  before_action :load_project, only: [:index, :create]
  before_action :load_task,    only: [:show, :edit, :update, :destroy, :move, :quick_update]

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
  end

  def show; end

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
      # Trong panel thì quay lại chính công việc đó (Turbo nạp lại vào panel),
      # ngoài panel thì về nơi vừa bấm.
      if turbo_frame_request?
        redirect_to task_path(@task)
      else
        redirect_back fallback_location: task_path(@task), notice: "Đã lưu công việc #{@task.code}."
      end
    else
      redirect_back fallback_location: task_path(@task), alert: @task.errors.full_messages.to_sentence
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

  # Sửa nhanh một trường từ panel chi tiết.
  def quick_update
    if @task.update(task_params)
      respond_to do |format|
        format.json { render json: { ok: true } }
        format.html { redirect_back fallback_location: task_path(@task) }
      end
    else
      render json: { error: { message: @task.errors.full_messages.to_sentence } }, status: :unprocessable_entity
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

  def task_params
    params.require(:task).permit(:title, :description, :priority, :assignee_id, :board_column_id,
                                 :start_date, :due_date, :estimated_hours, :status, :project_id, files: [])
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

  def authorize_owner_or_admin!(creator_id)
    return if current_user.role_admin? || creator_id == current_user.id
    raise Pundit::NotAuthorizedError
  end
end
