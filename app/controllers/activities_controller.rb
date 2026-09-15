class ActivitiesController < ApplicationController
  def index
    # Thao tác trên dự án mình không tham gia thì không hiện; việc chung
    # workspace (project_id rỗng) thì ai cũng thấy.
    @activities = Activity.newest.includes(:user, :project, :trackable)
    unless current_user.role_admin?
      @activities = @activities.where(project_id: [nil, *visible_project_ids])
    end
    @activities = @activities.where(user_id: params[:user_id])       if params[:user_id].present?
    @activities = @activities.where(project_id: params[:project_id]) if params[:project_id].present?
    @activities = @activities.where(action: params[:action_type])    if params[:action_type].present?
    if params[:from].present?
      @activities = @activities.where("activities.created_at >= ?", Date.parse(params[:from]).beginning_of_day)
    end
    if params[:to].present?
      @activities = @activities.where("activities.created_at <= ?", Date.parse(params[:to]).end_of_day)
    end
    @pagy       = Pagination.new(@activities, page: params[:page])
    @activities = @pagy.records
    @users    = User.alphabetical
    @projects = visible_projects.order(:name)
  rescue Date::Error
    redirect_to activities_path, alert: "Khoảng ngày không hợp lệ."
  end
end
