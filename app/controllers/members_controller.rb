class MembersController < ApplicationController
  before_action :require_admin!, only: [:invite, :resend_invitation, :disable, :enable, :update, :destroy]
  before_action :load_member,    only: [:show, :update, :resend_invitation, :disable, :enable, :destroy]

  def index
    @members = User.order(Arel.sql("CASE status WHEN 1 THEN 0 WHEN 0 THEN 1 ELSE 2 END"), :full_name)
    @project_counts = ProjectMembership.group(:user_id).count
    @pending = @members.count { |m| m.status_invited? }

    # Người nào đã để lại dấu vết thì không cho xoá. Gom bằng vài truy vấn
    # tổng hợp thay vì hỏi từng người (tránh N+1 trên bảng thành viên).
    @has_content = [
      Project.unscoped.group(:owner_id).count, Project.unscoped.group(:created_by_id).count,
      Task.unscoped.group(:reporter_id).count, Task.unscoped.group(:assignee_id).count,
      Transaction.unscoped.group(:created_by_id).count,
      Comment.unscoped.group(:user_id).count,
      StrategyNode.unscoped.group(:created_by_id).count
    ].flat_map(&:keys).compact.to_set
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

  # Xoá vĩnh viễn — chỉ khi người đó chưa để lại dấu vết nào. Còn lại phải
  # dùng vô hiệu hoá, để dữ liệu cũ giữ đúng tên người làm (FR-AUTH-09).
  def destroy
    if @member.id == current_user.id
      return redirect_to members_path, alert: "Không thể tự xoá tài khoản của chính mình."
    end

    if @member.role_admin? && User.where(role: User.roles[:admin]).count <= 1
      return redirect_to members_path, alert: "Đây là quản trị viên duy nhất — không xoá được."
    end

    blockers = @member.deletion_blockers
    if blockers.any?
      detail = blockers.map { |label, count| "#{count} #{label}" }.to_sentence
      return redirect_to members_path,
        alert: "Không xoá được #{@member.display_name}: đã có #{detail}. " \
               "Hãy dùng “Vô hiệu hoá” để giữ nguyên dữ liệu cũ mà vẫn chặn đăng nhập."
    end

    name = @member.display_name
    @member.destroy
    log_activity("deleted", summary: "đã xoá thành viên #{name}")
    redirect_to members_path, notice: "Đã xoá vĩnh viễn #{name}."
  end

  private

  def load_member   = @member = User.find(params[:id])
  def member_params = params.require(:user).permit(:role, :job_title, :full_name)
end
