class ProjectActivitiesController < ApplicationController
  def index
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
    @tab = "activity"
    @pagy       = Pagination.new(@project.activities.newest.includes(:user, :trackable), page: params[:page])
    @activities = @pagy.records
  end
end
