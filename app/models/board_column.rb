class BoardColumn < ApplicationRecord
  belongs_to :project
  has_many :tasks, dependent: :nullify

  validates :name, presence: true
  validates :key,  presence: true, uniqueness: { scope: :project_id }

  before_validation :assign_key, on: :create
  before_validation :assign_position, on: :create

  scope :ordered, -> { order(:position) }

  def task_count  = tasks.kept.where.not(status: Task.statuses[:cancelled]).count
  def over_wip?   = wip_limit.present? && wip_limit.positive? && task_count > wip_limit

  private

  def assign_key
    self.key ||= name.to_s.parameterize.presence || "col-#{SecureRandom.hex(3)}"
    self.key = "#{key}-#{SecureRandom.hex(2)}" if project&.board_columns&.where(key: key)&.exists?
  end

  def assign_position
    self.position ||= (project&.board_columns&.maximum(:position) || -1) + 1
  end
end
