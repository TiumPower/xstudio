class CommentsController < ApplicationController
  def create
    @commentable = find_commentable
    @comment = @commentable.comments.new(comment_params.merge(user: current_user))

    if @comment.save
      Comments::ProcessMentions.new(@comment, actor: current_user).call
      Notifications::Dispatch.comment_added(@comment, actor: current_user)
      log_activity("commented", trackable: @commentable, project: @comment.project,
                   summary: "đã bình luận trên #{commentable_label(@commentable)}")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path }
      end
    else
      redirect_back fallback_location: root_path, alert: "Bình luận không được để trống."
    end
  end

  def update
    @comment = Comment.kept.find(params[:id])
    raise Pundit::NotAuthorizedError unless @comment.user_id == current_user.id

    @comment.update(comment_params.merge(edited_at: Time.current))
    Comments::ProcessMentions.new(@comment, actor: current_user).call
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def destroy
    @comment = Comment.kept.find(params[:id])
    raise Pundit::NotAuthorizedError unless @comment.user_id == current_user.id || current_user.role_admin?

    @comment.discard
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def comment_params = params.require(:comment).permit(:body, files: [])

  def find_commentable
    if params[:task_code].present?    then Task.kept.find_by!(code: params[:task_code])
    elsif params[:project_code].present? then Project.kept.find_by!(code: params[:project_code])
    else raise ActiveRecord::RecordNotFound
    end
  end

  def commentable_label(c) = c.is_a?(Task) ? "công việc #{c.code}" : "dự án #{c.code}"
end
