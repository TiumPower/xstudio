class AiSuggestionLog < ApplicationRecord
  enum :mode,   { children: 0, subtree: 1 }, prefix: true
  enum :status, { success: 0, failed: 1, cancelled: 2 }, prefix: true

  belongs_to :user
  belongs_to :strategy_node, optional: true

  DAILY_LIMIT = 30 # BR-21

  # Lượt failed / cancelled không tính vào hạn mức.
  def self.used_today(user)
    where(user: user, status: statuses[:success])
      .where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
      .count
  end

  def self.remaining_today(user) = [DAILY_LIMIT - used_today(user), 0].max
end
