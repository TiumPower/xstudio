class Subtask < ApplicationRecord
  belongs_to :task, counter_cache: :subtasks_count

  validates :title, presence: true

  scope :ordered, -> { order(:position, :id) }

  after_save    :refresh_task_counters
  after_destroy :refresh_task_counters

  before_validation on: :create do
    self.position ||= (task&.subtasks&.maximum(:position) || -1) + 1
  end

  private

  def refresh_task_counters
    # Khi xoá cả công việc, Rails xoá việc con trước rồi mới xoá công việc —
    # lúc đó không được ghi ngược lên bản ghi đang bị huỷ.
    return if task.nil? || task.destroyed? || destroyed_by_association
    task.update_column(:done_subtasks_count, task.subtasks.where(done: true).count)
  end
end
