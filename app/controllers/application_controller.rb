class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_sentry_context
  helper_method :current_workspace, :unread_notifications_count, :my_open_overdue_count,
                :current_project

  rescue_from Pundit::NotAuthorizedError, with: :deny_access

  def current_workspace
    @current_workspace ||= Workspace.current
  end

  # Dự án đang mở, nếu có — để nút "Tạo mới" trên thanh trên gắn sẵn dự án đó.
  def current_project
    @project if defined?(@project) && @project.is_a?(Project) && @project.persisted?
  end

  def unread_notifications_count
    return 0 unless user_signed_in?
    @unread_notifications_count ||= current_user.notifications.unread.count
  end

  def my_open_overdue_count
    return 0 unless user_signed_in?
    @my_open_overdue_count ||= Task.kept.open_tasks
                                   .where(assignee_id: current_user.id)
                                   .where("tasks.due_date < ?", Date.current).count
  end

  protected

  def after_sign_in_path_for(_resource) = stored_location_for(:user) || root_path
  def after_sign_out_path_for(_scope)   = new_user_session_path

  def require_admin!
    return if current_user&.role_admin?
    deny_access
  end

  def deny_access
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: "Bạn không có quyền thực hiện thao tác này." }
      format.json { render json: { error: { message: "Không có quyền" } }, status: :forbidden }
      format.turbo_stream { redirect_back fallback_location: root_path, alert: "Bạn không có quyền thực hiện thao tác này." }
    end
  end

  def set_sentry_context
    return unless defined?(Sentry) && Sentry.initialized?
    Sentry.set_user(id: current_user&.id, email: current_user&.email)
  end

  # Ghi nhật ký hoạt động gọn trong controller.
  def log_activity(action, trackable: nil, project: nil, summary: nil, changes_payload: {})
    Activity.log!(user: current_user, action: action, trackable: trackable,
                  project: project, summary: summary, changes_payload: changes_payload)
  end
end
