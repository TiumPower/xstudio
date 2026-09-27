class BoardsController < ApplicationController
  include BoardScope

  before_action :load_project

  def show
    @tab = "kanban"
    load_board
    # Danh sách cho hộp "chuyển sang dự án khác" trên thẻ; kèm cả dự án hiện tại
    # để ô chọn mở ra là thấy việc đang ở đâu.
    @movable_projects = visible_projects.where(archived_at: nil)
                                        .or(visible_projects.where(id: @project.id))
                                        .order(:name)
  end

  private

  def load_project
    @project = Project.kept.includes(:members).find_by!(code: params[:project_code])
    authorize_project!(@project)
  end
end
