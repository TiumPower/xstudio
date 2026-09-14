class SubtasksController < ApplicationController
  before_action :load_task

  def create
    @subtask = @task.subtasks.create(subtask_params)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: task_path(@task) }
    end
  end

  def update
    @subtask = @task.subtasks.find(params[:id])
    @subtask.update(subtask_params)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: task_path(@task) }
    end
  end

  def destroy
    @subtask = @task.subtasks.find(params[:id])
    @subtask.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: task_path(@task) }
    end
  end

  private

  def load_task = @task = Task.kept.find_by!(code: params[:task_code])
  def subtask_params = params.require(:subtask).permit(:title, :done, :position)
end
