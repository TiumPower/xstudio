class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }

  before_validation { self.joined_at ||= Time.current }
end
