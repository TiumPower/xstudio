class TransactionCategory < ApplicationRecord
  enum :kind, { income: 0, expense: 1 }, prefix: true

  has_many :transactions, foreign_key: :category_id, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :kind, case_sensitive: false }

  scope :active,  -> { where(is_active: true) }
  scope :ordered, -> { order(:position, :name) }

  DEFAULT_INCOME  = ["Thanh toán hợp đồng", "Tạm ứng từ khách hàng", "Doanh thu sản phẩm", "Khác"].freeze
  DEFAULT_EXPENSE = ["Nhân sự & Outsource", "Hạ tầng & Cloud", "Phần mềm & Công cụ",
                     "Marketing & Bán hàng", "Văn phòng", "Đi lại & Tiếp khách",
                     "Thuế & Phí", "Khác"].freeze

  def self.seed_defaults!
    DEFAULT_INCOME.each_with_index  { |n, i| find_or_create_by!(name: n, kind: :income)  { |c| c.position = i } }
    DEFAULT_EXPENSE.each_with_index { |n, i| find_or_create_by!(name: n, kind: :expense) { |c| c.position = i } }
  end
end
