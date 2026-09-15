class ProjectResourcesController < ApplicationController
  before_action :load_project
  before_action :load_resource, only: [:update, :destroy]

  def create
    resource = @project.project_resources.new(resource_params)
    resource.created_by = current_user

    if resource.save
      log_activity("created", trackable: @project, project: @project,
                   summary: "đã thêm #{label_for(resource.kind)} “#{resource.label}” vào #{@project.name}")
      redirect_to project_product_path(@project), notice: "Đã thêm #{label_for(resource.kind)}."
    else
      redirect_to project_product_path(@project), alert: resource.errors.full_messages.to_sentence
    end
  end

  def update
    if @resource.update(resource_params)
      redirect_to project_product_path(@project), notice: "Đã lưu thay đổi."
    else
      redirect_to project_product_path(@project), alert: @resource.errors.full_messages.to_sentence
    end
  end

  def destroy
    label = @resource.label
    @resource.destroy
    log_activity("deleted", trackable: @project, project: @project,
                 summary: "đã xoá “#{label}” khỏi #{@project.name}")
    redirect_to project_product_path(@project), notice: "Đã xoá “#{label}”."
  end

  private

  def load_project
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
  end

  def load_resource = @resource = @project.project_resources.find(params[:id])

  def resource_params
    params.require(:project_resource).permit(:kind, :label, :url, :username, :note, :position, :file)
  end

  def label_for(kind)
    { "link" => "liên kết", "account" => "tài khoản", "doc" => "tài liệu" }[kind.to_s] || "mục"
  end
end
