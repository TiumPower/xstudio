class BoardsController < ApplicationController
  include BoardScope

  before_action :load_project

  def show
    @tab = "kanban"
    load_board
  end

  private

  def load_project
    @project = Project.kept.includes(:members).find_by!(code: params[:project_code])
    authorize_project!(@project)
  end
end
