class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true

  EVENT_TYPES = %w[
    invited_to_workspace task_assigned added_to_project mentioned comment_added
    task_status_changed task_due_soon task_overdue project_status_changed
  ].freeze

  scope :unread, -> { where(read_at: nil) }
  scope :newest, -> { order(created_at: :desc) }

  def read? = read_at.present?

  def mark_read!
    update_column(:read_at, Time.current) unless read?
  end
end
