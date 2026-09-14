class BoardsController < ApplicationController
  before_action :load_project

  def show
    @tab     = "kanban"
    @columns = @project.board_columns.ordered.to_a
    scope    = @project.tasks.kept.where.not(status: Task.statuses[:cancelled])
               .includes(:assignee, :labels).ordered

    scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    scope = scope.where(priority: params[:priority])       if params[:priority].present?
    scope = scope.joins(:labels).where(labels: { id: params[:label_id] }) if params[:label_id].present?
    case params[:due]
    when "overdue"   then scope = scope.where("tasks.due_date < ?", Date.current)
    when "this_week" then scope = scope.where(due_date: Date.current..Date.current.end_of_week)
    when "none"      then scope = scope.where(due_date: nil)
    end

    @tasks_by_column = scope.group_by(&:board_column_id)
    @labels = @project.labels.order(:name)
  end

  private

  def load_project
    @project = Project.kept.includes(:members).find_by!(code: params[:project_code])
  end
end
