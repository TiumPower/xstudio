class MembersController < ApplicationController
  before_action :require_admin!, only: [:invite, :resend_invitation, :disable, :enable, :update]
  before_action :load_member,    only: [:show, :update, :resend_invitation, :disable, :enable]

  def index
    @members = User.order(Arel.sql("CASE status WHEN 1 THEN 0 WHEN 0 THEN 1 ELSE 2 END"), :full_name)
    @project_counts = ProjectMembership.group(:user_id).count
    @pending = @members.count { |m| m.status_invited? }
  end

  def show
    @projects = @member.projects.kept.order(:name)
    @open_tasks = Task.kept.open_tasks.where(assignee_id: @member.id).includes(:project).order(Arel.sql("due_date NULLS LAST")).limit(20)
  end

  def invite
    emails = params[:emails].to_s.split(/[,\n;\s]+/).map(&:strip).reject(&:blank?).uniq
    if emails.empty?
      redirect_to members_path, alert: "Hãy nhập ít nhất một địa chỉ email."
      return
    end

    invited, failed = [], []
    emails.each do |email|
      user = User.invite!(email: email, invited_by: current_user)
      user.persisted? ? invited << user : failed << email
    rescue ActiveRecord::RecordInvalid => e
      failed << "#{email} (#{e.record.errors.full_messages.first})"
    end

    invited.each do |user|
      InvitationMailer.invite(user.id).deliver_later
      Notification.create!(user: user, event_type: "invited_to_workspace",
                           title: "Bạn được mời vào #{current_workspace.name}",
                           url: root_path, actor: current_user, created_at: Time.current)
    end
    log_activity("invited", summary: "đã mời #{invited.size} thành viên mới") if invited.any?

    notice = invited.any? ? "Đã gửi lời mời tới #{invited.size} email." : nil
    alert  = failed.any?  ? "Không mời được: #{failed.join(', ')}." : nil
    redirect_to members_path, notice: notice, alert: alert
  end

  def resend_invitation
    @member.generate_invitation_token
    @member.save!
    InvitationMailer.invite(@member.id).deliver_later
    redirect_to members_path, notice: "Đã gửi lại lời mời tới #{@member.email}."
  end

  def update
    if @member.update(member_params)
      redirect_to members_path, notice: "Đã cập nhật #{@member.display_name}."
    else
      redirect_to members_path, alert: @member.errors.full_messages.to_sentence
    end
  end

  # FR-AUTH-09 — vô hiệu hoá, không xoá.
  def disable
    if @member.id == current_user.id
      redirect_to members_path, alert: "Không thể tự vô hiệu hoá tài khoản của chính mình."
      return
    end
    @member.update!(status: :disabled)
    redirect_to members_path, notice: "Đã vô hiệu hoá #{@member.display_name}."
  end

  def enable
    @member.update!(status: @member.invitation_accepted_at ? :active : :invited)
    redirect_to members_path, notice: "Đã kích hoạt lại #{@member.display_name}."
  end

  private

  def load_member   = @member = User.find(params[:id])
  def member_params = params.require(:user).permit(:role, :job_title, :full_name)
end
