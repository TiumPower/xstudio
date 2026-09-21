class BoardColumnsController < ApplicationController
  include BoardScope

  before_action :load_project

  def create
    column = @project.board_columns.new(column_params)
    if column.save
      redraw_board notice: "Đã thêm cột #{column.name}."
    else
      redraw_board alert: column.errors.full_messages.to_sentence
    end
  end

  def update
    column = @project.board_columns.find(params[:id])
    if column.update(column_params)
      redraw_board notice: "Đã lưu cột."
    else
      redraw_board alert: column.errors.full_messages.to_sentence
    end
  end

  def destroy
    column = @project.board_columns.find(params[:id])
    if @project.board_columns.count <= 1
      return redraw_board(alert: "Dự án phải có ít nhất một cột.")
    end

    fallback = @project.board_columns.where.not(id: column.id).ordered.first
    column.tasks.update_all(board_column_id: fallback.id)
    column.destroy
    redraw_board notice: "Đã xoá cột. Công việc trong cột đã chuyển sang “#{fallback.name}”."
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, index|
      @project.board_columns.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  # Sửa cột là việc làm ngay trên bảng, nạp lại cả trang thì mất chỗ đang cuộn.
  # Vẽ lại đúng phần bảng và dải thông báo.
  def redraw_board(notice: nil, alert: nil)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice if notice
        flash.now[:alert]  = alert  if alert
        load_board
        render turbo_stream: [turbo_stream.replace("kanban_board", partial: "boards/board"),
                              turbo_stream.replace("flash", partial: "layouts/flash")]
      end
      format.html { redirect_to project_board_path(@project), notice: notice, alert: alert }
    end
  end

  def load_project
    @project = Project.kept.includes(:members).find_by!(code: params[:project_code])
    authorize_project!(@project)
  end

  def column_params
    permitted = params.require(:board_column).permit(:name, :color, :wip_limit, :is_done_column, :position)
    permitted[:wip_limit] = nil if permitted[:wip_limit].blank?
    permitted
  end
end
