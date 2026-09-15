class NotificationsController < ApplicationController
  def index
    scope = current_user.notifications.newest.includes(:actor)

    if params[:compact]
      return render partial: "notifications/dropdown_frame", locals: { notifications: scope.limit(10) }
    end

    @pagy          = Pagination.new(scope, page: params[:page])
    @notifications = @pagy.records
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
