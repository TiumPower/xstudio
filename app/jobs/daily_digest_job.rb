# FR-NOTI-03 — bản tin 08:00 giờ Việt Nam.
class DailyDigestJob < ApplicationJob
  queue_as :mailers

  def perform
    User.where(status: User.statuses[:active], daily_digest_enabled: true).find_each do |user|
      DigestMailer.daily(user.id).deliver_later
    end
  end
end
