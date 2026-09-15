class ProjectMembershipsController < ApplicationController
  before_action :load_project

  def create
    users = User.where(id: Array(params[:user_ids]).reject(&:blank?))
    users.each { |u| @project.project_memberships.find_or_create_by!(user: u) { |m| m.joined_at = Time.current } }
    Notifications::Dispatch.added_to_project(@project, users.to_a - [current_user], actor: current_user)
    log_activity("updated", trackable: @project, project: @project,
                 summary: "đã thêm #{users.map(&:display_name).to_sentence} vào dự án")
    redirect_to project_members_path(@project), notice: "Đã thêm thành viên."
  end

  def destroy
    membership = @project.project_memberships.find(params[:id])
    open_count = @project.tasks.kept.open_tasks.where(assignee_id: membership.user_id).count

    if open_count.positive? && params[:force].blank?
      redirect_to project_members_path(@project),
                  alert: "#{membership.user.display_name} còn #{open_count} công việc đang mở. " \
                         "Hãy chuyển giao hoặc bỏ gán trước khi gỡ khỏi dự án."
      return
    end

    @project.tasks.kept.open_tasks.where(assignee_id: membership.user_id).update_all(assignee_id: nil)
    membership.destroy
    redirect_to project_members_path(@project), notice: "Đã gỡ khỏi dự án."
  end

  private

  def load_project
    @project = Project.kept.find_by!(code: params[:project_code])
    authorize_project!(@project)
  end
end
