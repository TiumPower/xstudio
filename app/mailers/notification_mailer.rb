class NotificationMailer < ApplicationMailer
  SUBJECT_PREFIX = {
    "task_assigned"          => "Công việc mới",
    "added_to_project"       => "Dự án",
    "mentioned"              => "Bạn được nhắc tên",
    "comment_added"          => "Bình luận mới",
    "task_status_changed"    => "Công việc đổi trạng thái",
    "task_due_soon"          => "Sắp đến hạn",
    "task_overdue"           => "Quá hạn",
    "project_status_changed" => "Dự án đổi trạng thái"
  }.freeze

  def event(notification_id)
    @notification = Notification.find_by(id: notification_id)
    return if @notification.nil?

    @user = @notification.user
    return unless @user.email_enabled_for?(@notification.event_type)

    @cta_url = full_url(@notification.url)
    @notification.update_column(:emailed_at, Time.current)

    mail to: @user.email,
         subject: "[#{@workspace.name}] #{SUBJECT_PREFIX[@notification.event_type] || 'Thông báo'}: #{@notification.title}"
  end

  private

  def full_url(path)
    return root_url(host: mail_host) if path.blank?
    path.start_with?("http") ? path : "https://#{mail_host}#{path}"
  end

  def mail_host = ENV.fetch("APP_HOST", "xstudio.czin.net")
end
