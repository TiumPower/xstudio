class BoardColumnsController < ApplicationController
  before_action :load_project

  def create
    column = @project.board_columns.new(column_params)
    if column.save
      redirect_to project_board_path(@project), notice: "Đã thêm cột #{column.name}."
    else
      redirect_to project_board_path(@project), alert: column.errors.full_messages.to_sentence
    end
  end

  def update
    column = @project.board_columns.find(params[:id])
    if column.update(column_params)
      redirect_back fallback_location: project_board_path(@project), notice: "Đã lưu cột."
    else
      redirect_back fallback_location: project_board_path(@project), alert: column.errors.full_messages.to_sentence
    end
  end

  def destroy
    column = @project.board_columns.find(params[:id])
    if @project.board_columns.count <= 1
      redirect_to project_board_path(@project), alert: "Dự án phải có ít nhất một cột."
      return
    end

    fallback = @project.board_columns.where.not(id: column.id).ordered.first
    column.tasks.update_all(board_column_id: fallback.id)
    column.destroy
    redirect_to project_board_path(@project), notice: "Đã xoá cột. Công việc trong cột đã chuyển sang “#{fallback.name}”."
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, index|
      @project.board_columns.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def load_project
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
  end

  def column_params
    permitted = params.require(:board_column).permit(:name, :color, :wip_limit, :is_done_column, :position)
    permitted[:wip_limit] = nil if permitted[:wip_limit].blank?
    permitted
  end
end
