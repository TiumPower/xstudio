class ProjectMembersController < ApplicationController
  before_action :load_project

  def index
    @tab = "members"
    @memberships = @project.project_memberships.includes(:user).to_a
    @candidates  = User.assignable.where.not(id: @memberships.map(&:user_id))
    @open_counts = @project.tasks.kept.open_tasks.group(:assignee_id).count
  end

  private

  def load_project
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
  end
end
