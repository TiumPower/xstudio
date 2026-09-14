class ActivitiesController < ApplicationController
  def index
    @activities = Activity.newest.includes(:user, :project, :trackable)
    @activities = @activities.where(user_id: params[:user_id])       if params[:user_id].present?
    @activities = @activities.where(project_id: params[:project_id]) if params[:project_id].present?
    @activities = @activities.where(action: params[:action_type])    if params[:action_type].present?
    if params[:from].present?
      @activities = @activities.where("activities.created_at >= ?", Date.parse(params[:from]).beginning_of_day)
    end
    if params[:to].present?
      @activities = @activities.where("activities.created_at <= ?", Date.parse(params[:to]).end_of_day)
    end
    @activities = @activities.limit(300)
    @users    = User.alphabetical
    @projects = Project.kept.order(:name)
  rescue Date::Error
    redirect_to activities_path, alert: "Khoảng ngày không hợp lệ."
  end
end
