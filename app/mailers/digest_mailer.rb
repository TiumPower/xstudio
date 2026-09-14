# FR-NOTI-03 — bản tin tổng hợp hàng ngày, gửi 08:00 giờ Việt Nam.
class DigestMailer < ApplicationMailer
  def daily(user_id)
    @user = User.find_by(id: user_id)
    return if @user.nil? || !@user.status_active? || !@user.daily_digest_enabled?

    scope      = Task.kept.open_tasks.where(assignee_id: @user.id)
    @overdue   = scope.where("due_date < ?", Date.current).includes(:project).order(:due_date).to_a
    @due_today = scope.where(due_date: Date.current).includes(:project).to_a
    @due_week  = scope.where(due_date: (Date.current + 1)..Date.current.end_of_week).includes(:project).order(:due_date).to_a
    @activities = Activity.where(created_at: 1.day.ago.beginning_of_day..1.day.ago.end_of_day)
                          .where.not(user_id: @user.id).newest.includes(:user).limit(15).to_a

    return if @overdue.empty? && @due_today.empty? && @due_week.empty? && @activities.empty?

    @host = ENV.fetch("APP_HOST", "xstudio.czin.net")
    mail to: @user.email, subject: "[#{@workspace.name}] Bản tin ngày #{I18n.l(Date.current)}"
  end
end
