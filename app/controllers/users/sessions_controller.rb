class Users::SessionsController < Devise::SessionsController
  # Devise không tự trộn module này vào controller — phải include mới có
  # remember_me(resource).
  include Devise::Controllers::Rememberable

  layout "auth"
  before_action :configure_permitted_parameters
  skip_before_action :authenticate_user!, raise: false

  # Phiên đăng nhập không giới hạn: luôn bật "ghi nhớ" dù người dùng có tick
  # hay không, để đóng trình duyệt rồi mở lại vẫn còn đăng nhập.
  #
  # Sửa params trong before_action không ăn thua — Warden đã đọc tham số trước
  # đó rồi. Phải gọi remember_me sau khi xác thực xong, đúng cách Devise chỉ.
  def create
    super do |user|
      remember_me(user)
    end
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:remember_me])
  end
end
