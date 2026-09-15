class Project < ApplicationRecord
  include Discard::Model
  include Searchable

  PRODUCT_SALES_COLOR = "#6D3BD4".freeze
  DX_COLOR            = "#0E7490".freeze

  enum :project_type,  { product_sales: 0, digital_transformation: 1 }
  enum :status,        { planning: 0, in_progress: 1, on_hold: 2, completed: 3, cancelled: 4 }, prefix: true
  enum :progress_mode, { auto: 0, manual: 1 }, prefix: :progress

  belongs_to :owner,      class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :project_memberships, dependent: :destroy
  has_many :members, through: :project_memberships, source: :user
  has_many :board_columns, -> { order(:position) }, dependent: :destroy
  has_many :tasks,         dependent: :destroy
  has_many :labels,        dependent: :destroy
  has_many :transactions,  dependent: :nullify
  has_many :activities,    dependent: :nullify
  has_many :comments, as: :commentable, dependent: :destroy

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :manual_progress, numericality: { in: 0..100 }
  validate  :due_after_start

  before_validation :assign_code,  on: :create
  before_validation :assign_color, on: :create
  after_create      :create_default_board_columns
  after_create      :ensure_owner_membership

  # ---- Ai thấy dự án nào -------------------------------------------------
  #
  # Quản trị thấy tất cả. Thành viên chỉ thấy dự án mình được thêm vào —
  # kể cả dự án mình tạo ra hay phụ trách (cả hai trường hợp đó đều đã tự
  # thành thành viên, xem BR-10).
  scope :visible_to, ->(user) {
    next all if user.nil? || user.role_admin?
    where(id: ProjectMembership.where(user_id: user.id).select(:project_id))
  }

  def visible_to?(user)
    user.present? && (user.role_admin? || member?(user))
  end

  scope :active,      -> { kept.where(archived_at: nil) }
  scope :archived,    -> { kept.where.not(archived_at: nil) }
  scope :open_status, -> { where(status: [statuses[:planning], statuses[:in_progress], statuses[:on_hold]]) }
  scope :recent,      -> { order(updated_at: :desc) }

  # ---- Mã dự án (BR-01) --------------------------------------------------
  CODE_PREFIX = { "product_sales" => "PRD", "digital_transformation" => "DX" }.freeze

  def self.next_code(project_type)
    prefix = CODE_PREFIX[project_type.to_s] || "PRJ"
    last   = unscoped.where("code ~ ?", "^#{prefix}-[0-9]+$").order(Arel.sql("length(code), code")).last
    number = last ? last.code.split("-").last.to_i + 1 : 1
    format("%s-%03d", prefix, number)
  end

  def prefix = CODE_PREFIX[project_type.to_s] || "PRJ"

  # ---- Tiến độ (BR-02) ---------------------------------------------------
  def progress
    return manual_progress if progress_manual?
    counted = tasks.kept.where.not(status: Task.statuses[:cancelled])
    total   = counted.count
    return 0 if total.zero?
    ((counted.where(status: Task.statuses[:done]).count.to_f / total) * 100).round
  end

  # ---- Tài chính (BR-05) -------------------------------------------------
  def income_total  = transactions.kept.income.sum(:amount)
  def expense_total = transactions.kept.expense.sum(:amount)
  def profit        = income_total - expense_total

  # ---- Trạng thái hiển thị ----------------------------------------------
  def overdue?
    due_date.present? && due_date < Date.current && !status_completed? && !status_cancelled?
  end

  def archived?  = archived_at.present?
  def archive!   = update!(archived_at: Time.current)
  def unarchive! = update!(archived_at: nil)

  def type_color = product_sales? ? PRODUCT_SALES_COLOR : DX_COLOR
  def type_label = I18n.t("project_types.#{project_type}")

  def to_param = code

  def member?(user) = user.present? && project_memberships.exists?(user_id: user.id)

  def next_task_sequence
    (tasks.unscope(where: :discarded_at).maximum(Arel.sql("CAST(split_part(code, '-', array_length(string_to_array(code,'-'),1)) AS INTEGER)")) || 0) + 1
  end

  private

  DEFAULT_COLUMNS = [
    { key: "todo",   name: "Cần làm",   color: "#6B7A8F", is_done_column: false },
    { key: "doing",  name: "Đang làm",  color: "#2E6BC0", is_done_column: false },
    { key: "review", name: "Chờ duyệt", color: "#D98324", is_done_column: false },
    { key: "done",   name: "Hoàn thành", color: "#0E7A46", is_done_column: true }
  ].freeze

  def create_default_board_columns
    DEFAULT_COLUMNS.each_with_index do |attrs, i|
      board_columns.create!(attrs.merge(position: i))
    end
  end

  def ensure_owner_membership
    # BR-10 — người phụ trách mặc định là thành viên dự án.
    project_memberships.find_or_create_by!(user_id: owner_id) { |m| m.joined_at = Time.current } if owner_id
  end

  def assign_code
    self.code = self.class.next_code(project_type) if code.blank?
  end

  def assign_color
    self.color ||= type_color
  end

  def due_after_start
    return if start_date.blank? || due_date.blank? || due_date >= start_date
    errors.add(:due_date, :before_start_date)
  end
end
