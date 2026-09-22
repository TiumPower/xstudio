require "faraday"

# Gửi email qua HTTP API của Brevo (HTTPS/443) thay vì SMTP — chạy được cả ở
# nơi chặn cổng SMTP ra ngoài. Dùng chung tài khoản Brevo với Loyalty/Estate.
#
# Bật khi có ENV["BREVO_API_KEY"] (xem production.rb + initializers/mail_delivery.rb).
class BrevoMailDelivery
  ENDPOINT = "https://api.brevo.com/v3/smtp/email".freeze

  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    key = ENV["BREVO_API_KEY"]
    if key.blank?
      Rails.logger.warn("[Brevo] thiếu BREVO_API_KEY — bỏ qua email tới #{Array(mail.to).join(', ')}")
      return
    end

    addr       = mail.header[:from]&.addrs&.first
    from_email = addr&.address.presence || Array(mail.from).first ||
                 ENV.fetch("MAIL_FROM", "no-reply@xstudio.tiumpower.com")
    from_name  = addr&.display_name.presence || ENV.fetch("MAIL_FROM_NAME", "Team Workspace")

    body = {
      sender:      { email: from_email, name: from_name },
      to:          Array(mail.to).map { |email| { email: email } },
      subject:     mail.subject,
      htmlContent: html_body(mail),
      textContent: text_body(mail)
    }.compact

    response = connection.post(ENDPOINT, JSON.generate(body))

    if response.status >= 300
      Rails.logger.error("[Brevo] #{response.status}: #{response.body.to_s.truncate(400)}")
      # Ném lỗi để job nền thử lại (ApplicationJob retry 3 lần).
      raise "Brevo trả về #{response.status}"
    end

    Rails.logger.info("[Brevo] đã gửi tới=#{Array(mail.to).join(',')} status=#{response.status}")
  end

  private

  def connection
    @connection ||= Faraday.new do |f|
      f.headers["api-key"]      = ENV["BREVO_API_KEY"].to_s
      f.headers["Content-Type"] = "application/json"
      f.headers["Accept"]       = "application/json"
      f.request :retry, max: 2, interval: 0.5, backoff_factor: 2,
                        retry_statuses: [429, 500, 502, 503]
      f.options.timeout      = 15
      f.options.open_timeout = 5
    end
  end

  def html_body(mail)
    mail.html_part&.body&.decoded || (mail.mime_type == "text/html" ? mail.body.decoded : nil)
  end

  def text_body(mail)
    mail.text_part&.body&.decoded || (mail.mime_type == "text/plain" ? mail.body.decoded : nil)
  end
end
