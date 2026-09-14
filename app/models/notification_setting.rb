class NotificationSetting < ApplicationRecord
  belongs_to :user
  validates :event_type, presence: true, uniqueness: { scope: :user_id }
end
