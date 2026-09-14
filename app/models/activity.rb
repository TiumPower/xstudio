class Activity < ApplicationRecord
  belongs_to :user,      optional: true
  belongs_to :trackable, polymorphic: true, optional: true
  belongs_to :project,   optional: true

  ACTIONS = %w[created updated deleted moved commented assigned archived restored
               invited status_changed node_created node_updated node_deleted node_moved].freeze

  scope :newest, -> { order(created_at: :desc) }
  scope :for_project, ->(p) { where(project_id: p) }

  def self.log!(user:, action:, trackable: nil, project: nil, summary: nil, changes_payload: {})
    create!(user: user, action: action.to_s, trackable: trackable, project: project,
            summary: summary, changes_payload: changes_payload || {}, created_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("[Activity] không ghi được nhật ký: #{e.message}")
    nil
  end
end
