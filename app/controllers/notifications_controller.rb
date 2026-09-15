class NotificationsController < ApplicationController
  def index
    scope = current_user.notifications.newest.includes(:actor)

    if params[:compact]
      return render partial: "notifications/dropdown_frame", locals: { notifications: scope.limit(10) }
    end

    @pagy          = Pagination.new(scope, page: params[:page])
    @notifications = @pagy.records
  end

  # Bấm vào một thông báo: đánh dấu đã đọc RỒI mới mở đối tượng.
  # Trước đây link trỏ thẳng tới đối tượng nên nó vẫn mãi ở trạng thái chưa đọc.
  def open
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!
    redirect_to(notification.url.presence || notifications_path, allow_other_host: false)
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
