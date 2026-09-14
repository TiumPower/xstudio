# FR-NOTI-02 ⑦⑧ — nhắc hạn trước 1 ngày và quét quá hạn. Chạy 07:30 mỗi ngày.
class DueReminderJob < ApplicationJob
  queue_as :default

  def perform
    Task.kept.open_tasks.where(due_date: Date.current + 1).includes(:assignee, :project).find_each do |task|
      next if already_notified?(task, "task_due_soon")
      Notifications::Dispatch.task_due_soon(task)
    end

    Task.kept.open_tasks.where("tasks.due_date < ?", Date.current).includes(:assignee, :project).find_each do |task|
      next if already_notified?(task, "task_overdue")
      Notifications::Dispatch.task_overdue(task)
    end
  end

  private

  # Mỗi task chỉ nhắc 1 lần/ngày cho mỗi loại.
  def already_notified?(task, event_type)
    return true if task.assignee_id.blank?
    Notification.where(user_id: task.assignee_id, event_type: event_type)
                .where("url = ?", Rails.application.routes.url_helpers.task_path(task))
                .where("notifications.created_at >= ?", Time.zone.now.beginning_of_day).exists?
  end
end
