class ApplicationMailer < ActionMailer::Base
  # Brevo chỉ cho gửi từ địa chỉ đã xác thực — cả nhà dùng chung no-reply@tiumpower.com,
  # chỉ khác tên hiển thị.
  default from: -> {
    address = ENV.fetch("MAIL_FROM", "no-reply@tiumpower.com")
    name    = ENV.fetch("MAIL_FROM_NAME", "Team Workspace")
    address.include?("<") ? address : %("#{name}" <#{address}>)
  }
  layout "mailer"

  helper :application

  before_action { @workspace = Workspace.current }
end
