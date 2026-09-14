class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.newest.includes(:actor)
    @notifications = @notifications.limit(params[:compact] ? 10 : 100)
    render partial: "notifications/dropdown", locals: { notifications: @notifications } if params[:compact]
  end

  def read
    current_user.notifications.find(params[:id]).mark_read!
    redirect_back fallback_location: notifications_path
  end

  def read_all
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back fallback_location: notifications_path, notice: "Đã đánh dấu tất cả là đã đọc."
  end
end
