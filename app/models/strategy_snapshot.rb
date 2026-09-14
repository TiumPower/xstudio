class StrategySnapshot < ApplicationRecord
  belongs_to :strategy_tree
  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true

  scope :newest, -> { order(created_at: :desc) }
  scope :automatic, -> { where(auto: true) }
end
