# Đăng ký cách gửi email qua Brevo. Phải nằm ở initializer vì production.rb
# được nạp trước khi autoload sẵn sàng.
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method(:brevo, BrevoMailDelivery)
end
