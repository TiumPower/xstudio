class ProjectsController < ApplicationController
  before_action :load_project, only: [:show, :edit, :update, :destroy, :archive, :unarchive]

  def index
    @view    = params[:view].presence_in(%w[cards table]) || "cards"
    @scope   = params[:scope].presence_in(%w[active archived]) || "active"
    @projects = (@scope == "archived" ? Project.archived : Project.active)
                .includes(:owner, :members, :tasks)

    @projects = @projects.where(project_type: params[:type])   if params[:type].present?
    @projects = @projects.where(status: params[:status])       if params[:status].present?
    @projects = @projects.where(owner_id: params[:owner_id])   if params[:owner_id].present?
    @projects = @projects.where(client_name: params[:client])  if params[:client].present?
    if params[:q].present?
      like = "%#{params[:q].strip}%"
      @projects = @projects.where("projects.name ILIKE :q OR projects.code ILIKE :q OR projects.client_name ILIKE :q", q: like)
    end

    @projects = case params[:sort]
                when "due"      then @projects.order(Arel.sql("due_date NULLS LAST"))
                when "name"     then @projects.order(:name)
                when "progress" then @projects.order(updated_at: :desc)
                else @projects.recent
                end.to_a

    # Chỉ chế độ Thẻ hiện số tiền; chế độ Bảng không cần truy vấn tổng hợp này.
    @stats = @view == "cards" ? Finance::ProjectTotals.new(@projects.map(&:id)).call : {}
    @owners  = User.alphabetical.where(id: Project.kept.select(:owner_id))
    @clients = Project.kept.where.not(client_name: [nil, ""]).distinct.pluck(:client_name).sort
  end

  def show
    @tab = "overview"
    @upcoming_tasks = @project.tasks.kept.open_tasks.where.not(due_date: nil)
                              .where("due_date <= ?", 14.days.from_now).includes(:assignee)
                              .order(:due_date).limit(8)
    @recent_activities = @project.activities.newest.includes(:user).limit(10)
  end

  def new
    @project = Project.new(project_type: params[:type].presence || "digital_transformation",
                           status: :planning, owner: current_user, start_date: Date.current)
  end

  def create
    @project = Project.new(project_params)
    @project.created_by = current_user
    @project.owner    ||= current_user

    if @project.save
      sync_members
      log_activity("created", trackable: @project, project: @project,
                   summary: "đã tạo dự án #{@project.name}")
      Notifications::Dispatch.added_to_project(@project, @project.members - [current_user], actor: current_user)
      redirect_to project_path(@project), notice: "Đã tạo dự án #{@project.code}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    previous_status = @project.status
    if @project.update(project_params)
      sync_members
      log_activity("updated", trackable: @project, project: @project,
                   summary: "đã cập nhật dự án #{@project.name}")
      if previous_status != @project.status
        @project.update_column(:completed_at, Time.current) if @project.status_completed? && @project.completed_at.blank?
        Notifications::Dispatch.project_status_changed(@project, actor: current_user)
      end
      redirect_to project_path(@project), notice: "Đã lưu thay đổi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize_owner_or_admin!(@project.created_by_id)
    @project.discard
    log_activity("deleted", trackable: @project, project: @project, summary: "đã xoá dự án #{@project.name}")
    redirect_to projects_path, notice: "Đã xoá dự án #{@project.code}."
  end

  def archive
    @project.archive!
    log_activity("archived", trackable: @project, project: @project, summary: "đã lưu trữ dự án #{@project.name}")
    redirect_to projects_path, notice: "Đã lưu trữ dự án #{@project.code}."
  end

  def unarchive
    @project.unarchive!
    redirect_to project_path(@project), notice: "Đã bỏ lưu trữ."
  end

  private

  def load_project
    @project = Project.kept.includes(:owner, :members).find_by!(code: params[:code])
  end

  def project_params
    params.require(:project).permit(:name, :code, :description, :project_type, :status,
                                    :client_name, :start_date, :due_date, :owner_id,
                                    :color, :progress_mode, :manual_progress)
  end

  def sync_members
    ids = Array(params[:project][:member_ids]).reject(&:blank?).map(&:to_i)
    ids |= [@project.owner_id].compact
    existing = @project.project_memberships.pluck(:user_id)

    (ids - existing).each { |uid| @project.project_memberships.create(user_id: uid, joined_at: Time.current) }
    removable = existing - ids
    return if removable.empty?
    # BR-09 — không gỡ người còn task đang mở; bỏ gán trước.
    @project.tasks.kept.open_tasks.where(assignee_id: removable).update_all(assignee_id: nil)
    @project.project_memberships.where(user_id: removable).destroy_all
  end

  def authorize_owner_or_admin!(creator_id)
    return if current_user.role_admin? || creator_id == current_user.id
    raise Pundit::NotAuthorizedError
  end
end
