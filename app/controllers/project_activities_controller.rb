class ProjectActivitiesController < ApplicationController
  def index
    @project = Project.kept.find_by!(code: params[:project_code])
    @tab = "activity"
    @activities = @project.activities.newest.includes(:user, :trackable).limit(200)
  end
end
