# Tab "Sản phẩm" — chỉ có ở dự án loại Product, vì đó là sản phẩm của chính
# đội chứ không phải việc làm cho khách.
class ProductController < ApplicationController
  before_action :load_project

  def show
    @tab       = "product"
    @links     = @project.project_resources.kind_link.ordered
    @accounts  = @project.project_resources.kind_account.ordered
    @docs      = @project.project_resources.kind_doc.ordered.includes(file_attachment: :blob)
  end

  private

  def load_project
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
    return if @project.product?

    redirect_to project_path(@project),
                alert: "Tab Sản phẩm chỉ dành cho dự án loại Product."
  end
end
