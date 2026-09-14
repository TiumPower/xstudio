class Task < ApplicationRecord
  include Discard::Model

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }, prefix: true
  enum :status,   { open: 0, done: 1, cancelled: 2 },        prefix: true

  belongs_to :project
  belongs_to :board_column, optional: true
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :reporter, class_name: "User", optional: true

  has_rich_text :description
  has_many_attached :files

  has_many :subtasks,    -> { order(:position, :id) }, dependent: :destroy
  has_many :task_labels, dependent: :destroy
  has_many :labels, through: :task_labels
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true
  validates :code,  presence: true, uniqueness: true
  validate  :assignee_is_project_member

  before_validation :assign_code,     on: :create
  before_validation :assign_column,   on: :create
  before_validation :assign_position, on: :create
  before_save       :sync_status_with_column

  scope :open_tasks, -> { kept.where(status: statuses[:open]) }
  scope :overdue,    -> { open_tasks.where("due_date < ?", Date.current) }
  scope :ordered,    -> { order(:position, :id) }

  PRIORITY_COLORS = { "low" => "#94A3B8", "medium" => "#0EA5E9", "high" => "#D98324", "urgent" => "#C8322B" }.freeze

  def priority_color = PRIORITY_COLORS[priority]
  def priority_label = I18n.t("priorities.#{priority}")

  def overdue?      = due_date.present? && due_date < Date.current && status_open?
  def due_today?    = due_date == Date.current
  def due_this_week? = due_date.present? && due_date.between?(Date.current, Date.current.end_of_week)

  def subtask_summary = "#{done_subtasks_count}/#{subtasks_count}"

  def to_param = code

  # Chuyển task sang cột khác, giữ thứ tự bằng position kiểu decimal (mục 9.2).
  def move_to!(column, prev_position: nil, next_position: nil)
    self.board_column = column
    self.position = self.class.position_between(prev_position, next_position)
    save!
  end

  def self.position_between(prev_pos, next_pos)
    prev_pos = prev_pos&.to_d
    next_pos = next_pos&.to_d
    return (prev_pos + 1024) if next_pos.nil? && prev_pos
    return (next_pos - 1024) if prev_pos.nil? && next_pos
    return 1024.to_d          if prev_pos.nil? && next_pos.nil?
    ((prev_pos + next_pos) / 2)
  end

  private

  def assign_code
    return if code.present? || project.nil?
    self.code = "#{project.code}-#{project.next_task_sequence}"
  end

  def assign_column
    self.board_column ||= project&.board_columns&.ordered&.first
  end

  def assign_position
    self.position = (board_column&.tasks&.maximum(:position) || 0) + 1024
  end

  # BR-03 — cột "Hoàn thành" quyết định trạng thái task.
  def sync_status_with_column
    return if status_cancelled?
    if board_column&.is_done_column?
      self.status = :done
      self.completed_at ||= Time.current
    else
      self.status = :open
      self.completed_at = nil
    end
  end

  # BR-09 — chỉ gán cho người đã là thành viên dự án.
  def assignee_is_project_member
    return if assignee_id.blank? || project.nil?
    return if project.project_memberships.exists?(user_id: assignee_id)
    errors.add(:assignee_id, :not_a_project_member)
  end
end
