class ProjectResourcesController < ApplicationController
  before_action :load_project
  before_action :load_resource, only: [:show, :edit, :update, :destroy]

  # Trang đọc tài liệu — dùng cho cả tài liệu viết trong app lẫn tệp .md/.html
  # tải lên. Tệp định dạng khác thì không có gì để hiển thị, đưa thẳng về
  # trang Sản phẩm để tải xuống.
  def show
    return redirect_to project_product_path(@project) unless @resource.kind_doc?

    if !@resource.viewable?
      redirect_to rails_blob_path(@resource.file, disposition: "attachment")
    end
  end

  def new
    @resource = @project.project_resources.new(kind: :doc, content_format: :markdown)
  end

  def edit
    redirect_to project_product_path(@project) unless @resource.written?
  end

  def create
    @resource = @project.project_resources.new(resource_params)
    @resource.created_by = current_user

    if @resource.save
      log_activity("created", trackable: @project, project: @project,
                   summary: "đã thêm #{label_for(@resource.kind)} “#{@resource.label}” vào #{@project.name}")
      redirect_to after_save_path(@resource), notice: "Đã thêm #{label_for(@resource.kind)}."
    elsif @resource.kind_doc? && @resource.content.present?
      # Soạn thảo dài — quay lại đúng trang soạn, giữ nguyên chữ đã gõ.
      flash.now[:alert] = @resource.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    else
      redirect_to project_product_path(@project), alert: @resource.errors.full_messages.to_sentence
    end
  end

  def update
    if @resource.update(resource_params)
      redirect_to after_save_path(@resource), notice: "Đã lưu thay đổi."
    elsif @resource.written?
      flash.now[:alert] = @resource.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
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

  # Xem trước trong lúc gõ. Nội dung đi qua đúng bộ lọc của trang đọc, nên
  # thấy gì ở đây là thấy đúng cái sẽ hiện sau khi lưu — kể cả phần bị lọc bỏ.
  def preview
    html = Markup.render(params[:content].to_s, params[:content_format].presence || "markdown")
    render partial: "project_resources/preview", locals: { html: html }
  end

  private

  def load_project
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
  end

  def load_resource = @resource = @project.project_resources.find(params[:id])

  def resource_params
    params.require(:project_resource)
          .permit(:kind, :label, :url, :username, :note, :position, :file, :content, :content_format)
  end

  # Viết xong tài liệu thì mở luôn trang đọc; còn lại về trang Sản phẩm.
  def after_save_path(resource)
    resource.written? ? project_project_resource_path(@project, resource) : project_product_path(@project)
  end

  def label_for(kind)
    { "link" => "liên kết", "account" => "tài khoản", "doc" => "tài liệu" }[kind.to_s] || "mục"
  end
end
