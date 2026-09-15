class Transaction < ApplicationRecord
  include Discard::Model
  include Searchable

  self.table_name = "transactions"

  enum :kind,           { income: 0, expense: 1 }, prefix: true
  enum :payment_method, { cash: 0, bank_transfer: 1, card: 2, other: 3 }, prefix: :via

  belongs_to :category,   class_name: "TransactionCategory", optional: true
  belongs_to :project,    optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many_attached :receipts

  # BR-07 — amount luôn dương, đơn vị VND, số nguyên.
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :occurred_on, presence: true
  validate  :occurred_on_not_too_far_ahead

  scope :income,  -> { where(kind: kinds[:income]) }
  scope :expense, -> { where(kind: kinds[:expense]) }
  scope :general, -> { where(project_id: nil) }
  scope :in_period, ->(from, to) { where(occurred_on: from..to) }
  scope :newest,  -> { order(occurred_on: :desc, id: :desc) }

  def signed_amount = kind_income? ? amount : -amount
  def general?      = project_id.nil?
  def kind_label    = kind_income? ? "Thu" : "Chi"

  private

  # BR-08 — không ghi ngày ở tương lai quá 1 năm.
  def occurred_on_not_too_far_ahead
    return if occurred_on.blank? || occurred_on <= 1.year.from_now.to_date
    errors.add(:occurred_on, :too_far_in_future)
  end
end
