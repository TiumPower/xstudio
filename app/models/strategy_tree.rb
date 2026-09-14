class StrategyTree < ApplicationRecord
  include Discard::Model

  belongs_to :created_by, class_name: "User", optional: true
  has_many :strategy_nodes, dependent: :destroy
  has_many :strategy_snapshots, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :assign_slug
  before_validation :assign_position, on: :create
  after_create      :create_root_node

  scope :ordered, -> { kept.order(:position, :id) }

  def root = strategy_nodes.kept.find_by(parent_id: nil)

  # Tải toàn bộ cây trong MỘT truy vấn rồi dựng cấu trúc lồng nhau trong Ruby
  # (mục 9 — tuyệt đối tránh đệ quy gọi DB từng cấp).
  def nodes_tree
    all = strategy_nodes.kept.includes(:owner).order(:depth, :position, :id).to_a
    by_parent = all.group_by(&:parent_id)
    build = lambda do |node|
      { node: node, children: (by_parent[node.id] || []).map { |c| build.call(c) } }
    end
    root_node = all.find { |n| n.parent_id.nil? }
    root_node ? build.call(root_node) : nil
  end

  def node_count = strategy_nodes.kept.count

  def to_param = slug

  private

  def assign_slug
    return if slug.present? && !name_changed?
    base = name.to_s.parameterize.presence || "cay"
    candidate = base
    i = 2
    while StrategyTree.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end

  def assign_position
    self.position ||= (StrategyTree.maximum(:position) || -1) + 1
  end

  # BR-15 — cây luôn tồn tại đúng một nút gốc.
  def create_root_node
    strategy_nodes.create!(title: name.first(120), depth: 0, position: 0,
                           status: :pursuing, created_by: created_by, updated_by: created_by)
  end
end
