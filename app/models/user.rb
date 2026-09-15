class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable,
         :trackable, :lockable, :validatable

  enum :role,   { member: 0, admin: 1 },                          prefix: true
  enum :status, { invited: 0, active: 1, disabled: 2 },           prefix: true

  has_one_attached :avatar

  belongs_to :invited_by, class_name: "User", optional: true
  has_many   :invitees, class_name: "User", foreign_key: :invited_by_id, dependent: :nullify

  has_many :owned_projects,      class_name: "Project", foreign_key: :owner_id,      dependent: :nullify
  has_many :created_projects,    class_name: "Project", foreign_key: :created_by_id, dependent: :nullify
  has_many :project_memberships, dependent: :destroy
  has_many :projects,            through: :project_memberships
  has_many :assigned_tasks,      class_name: "Task", foreign_key: :assignee_id, dependent: :nullify
  has_many :reported_tasks,      class_name: "Task", foreign_key: :reporter_id, dependent: :nullify
  has_many :created_transactions, class_name: "Transaction", foreign_key: :created_by_id, dependent: :nullify
  has_many :comments,            dependent: :destroy
  has_many :mentions,            dependent: :destroy
  has_many :notifications,       dependent: :destroy
  has_many :acted_notifications, class_name: "Notification", foreign_key: :actor_id, dependent: :nullify
  has_many :notification_settings, dependent: :destroy
  has_many :activities,          dependent: :nullify
  has_many :ai_suggestion_logs,  dependent: :destroy
  has_many :created_trees,       class_name: "StrategyTree", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_snapshots,   class_name: "StrategySnapshot", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_nodes,       class_name: "StrategyNode", foreign_key: :created_by_id, dependent: :nullify
  has_many :updated_nodes,       class_name: "StrategyNode", foreign_key: :updated_by_id, dependent: :nullify
  has_many :owned_nodes,         class_name: "StrategyNode", foreign_key: :owner_id,      dependent: :nullify

  validates :full_name, presence: true
  validate  :password_has_letter_and_digit, if: -> { password.present? }

  before_validation :assign_avatar_color, on: :create

  scope :assignable, -> { where(status: [statuses[:active], statuses[:invited]]).order(:full_name) }
  scope :alphabetical, -> { order(:full_name) }

  # --- Lời mời ------------------------------------------------------------
  INVITATION_VALID_FOR = 7.days

  def self.invite!(email:, invited_by:, full_name: nil)
    user = find_or_initialize_by(email: email.to_s.downcase.strip)
    return user if user.persisted? && user.status_active?

    user.full_name ||= full_name.presence || email.to_s.split("@").first.to_s.tr(".", " ").split.map(&:capitalize).join(" ")
    user.full_name = user.full_name.presence || email.to_s.split("@").first
    user.invited_by  = invited_by
    user.status      = :invited
    user.password  ||= SecureRandom.hex(16)
    user.generate_invitation_token
    user.save!
    user
  end

  def generate_invitation_token
    self.invitation_token   = SecureRandom.urlsafe_base64(32)
    self.invitation_sent_at = Time.current
  end

  def invitation_valid?
    invitation_token.present? &&
      invitation_sent_at.present? &&
      invitation_sent_at > INVITATION_VALID_FOR.ago &&
      invitation_accepted_at.nil?
  end

  def accept_invitation!(attrs)
    assign_attributes(attrs)
    self.status                 = :active
    self.invitation_token       = nil
    self.invitation_accepted_at = Time.current
    save
  end

  # --- Devise hooks -------------------------------------------------------
  # Thành viên bị vô hiệu hoá hoặc chưa kích hoạt thì không đăng nhập được.
  def active_for_authentication?
    super && status_active?
  end

  def inactive_message
    status_disabled? ? :disabled_account : :not_activated
  end

  # --- Hiển thị -----------------------------------------------------------
  def initials
    parts = full_name.to_s.split.reject(&:blank?)
    return email.to_s[0, 2].upcase if parts.empty?
    (parts.length == 1 ? parts.first[0, 2] : "#{parts[-2][0]}#{parts[-1][0]}").upcase
  end

  def display_name = full_name.presence || email

  # ---- Xoá vĩnh viễn ------------------------------------------------------
  #
  # SRS (FR-AUTH-09) cố ý chỉ cho VÔ HIỆU HOÁ, để dữ liệu cũ còn giữ đúng tên
  # người làm. Nên chỉ cho xoá hẳn khi người đó chưa để lại dấu vết nào —
  # tức là mời nhầm, hoặc vào rồi chưa làm gì. Còn lại vẫn dùng vô hiệu hoá.
  def deletion_blockers
    {
      "dự án phụ trách"   => owned_projects.count,
      "dự án đã tạo"      => created_projects.count,
      "công việc đã tạo"  => reported_tasks.count,
      "công việc được giao" => assigned_tasks.count,
      "giao dịch đã ghi"  => created_transactions.count,
      "bình luận"         => comments.count,
      "nút định hướng đã tạo" => created_nodes.count
    }.reject { |_, count| count.zero? }
  end

  def deletable? = deletion_blockers.empty?

  def notification_setting_for(event_type)
    notification_settings.find_or_initialize_by(event_type: event_type.to_s)
  end

  def email_enabled_for?(event_type)
    return false unless status_active?
    setting = notification_settings.detect { |s| s.event_type == event_type.to_s }
    setting.nil? || setting.email_enabled
  end

  private

  AVATAR_COLORS = %w[#2E6BC0 #6D3BD4 #0E7490 #0E7A46 #D98324 #C8322B #5A6B82 #B4479E].freeze

  def assign_avatar_color
    self.avatar_color ||= AVATAR_COLORS[(full_name.to_s + email.to_s).sum % AVATAR_COLORS.size]
  end

  def password_has_letter_and_digit
    return if password.match?(/[A-Za-z]/) && password.match?(/\d/)
    errors.add(:password, :needs_letter_and_digit)
  end
end
