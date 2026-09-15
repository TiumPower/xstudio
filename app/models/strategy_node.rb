class StrategyNode < ApplicationRecord
  include Discard::Model
  include BroadcastsTreeChanges
  include Searchable

  MAX_DEPTH = 6 # không kể gốc (FR-TREE-02)

  enum :status, { idea: 0, pursuing: 1, paused: 2, achieved: 3, dropped: 4 }, prefix: true

  belongs_to :strategy_tree
  belongs_to :parent, class_name: "StrategyNode", optional: true, counter_cache: :children_count
  belongs_to :owner,      class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :children, -> { kept.order(:position, :id) },
           class_name: "StrategyNode", foreign_key: :parent_id, dependent: :destroy

  validates :title, presence: true, length: { maximum: 120 }
  validate  :depth_within_limit
  validate  :parent_not_descendant

  before_validation :assign_depth
  before_validation :assign_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  STATUS_COLORS = {
    "idea"     => "#6B7A8F",
    "pursuing" => "#2E6BC0",
    "paused"   => "#D98324",
    "achieved" => "#0E7A46",
    "dropped"  => "#C8322B"
  }.freeze

  LEVEL_COLORS = %w[#2E6BC0 #6D3BD4 #0E7490 #0E7A46 #D98324 #B4479E #5A6B82].freeze

  def root?        = parent_id.nil?
  def status_color = STATUS_COLORS[status]
  def status_label = I18n.t("node_statuses.#{status}")

  # BR-19 — kế thừa màu của tổ tiên gần nhất có màu.
  def effective_color
    node = self
    while node
      return node.color if node.color.present?
      node = node.parent
    end
    LEVEL_COLORS[[depth, LEVEL_COLORS.size - 1].min]
  end

  def descendant_ids
    ids   = []
    queue = StrategyNode.kept.where(parent_id: id).pluck(:id)
    until queue.empty?
      ids.concat(queue)
      queue = StrategyNode.kept.where(parent_id: queue).pluck(:id)
    end
    ids
  end

  def descendants_count = descendant_ids.size

  def path_titles
    titles = []
    node   = self
    while node
      titles.unshift(node.title)
      node = node.parent
    end
    titles
  end

  def subtree_max_depth
    ids  = [id]
    max  = depth
    loop do
      rows = StrategyNode.kept.where(parent_id: ids).pluck(:id, :depth)
      break if rows.empty?
      max = [max, rows.map(&:last).max].max
      ids = rows.map(&:first)
    end
    max
  end

  # BR-16 — di chuyển nút: cập nhật parent/position rồi tính lại depth cả nhánh,
  # tất cả trong một transaction (mục 9.7).
  def move_to!(new_parent:, prev_position: nil, next_position: nil)
    transaction do
      raise ArgumentError, :cycle if new_parent && (new_parent.id == id || descendant_ids.include?(new_parent.id))

      new_depth = new_parent ? new_parent.depth + 1 : 0
      span      = subtree_max_depth - depth
      raise ArgumentError, :too_deep if new_depth + span > MAX_DEPTH

      self.parent   = new_parent
      self.position = self.class.position_between(prev_position, next_position)
      self.depth    = new_depth
      save!
      recalculate_subtree_depth!
    end
    true
  end

  def recalculate_subtree_depth!
    level = [self]
    until level.empty?
      next_level = StrategyNode.kept.where(parent_id: level.map(&:id)).to_a
      next_level.each do |child|
        parent_depth = level.detect { |n| n.id == child.parent_id }.depth
        child.update_column(:depth, parent_depth + 1)
        child.depth = parent_depth + 1
      end
      level = next_level
    end
  end

  # BR-18 — xoá nút: cascade (cả nhánh) hoặc promote (đẩy con lên cấp trên).
  def discard_branch!(mode: :cascade)
    transaction do
      if mode.to_sym == :promote
        children.each do |child|
          child.update!(parent_id: parent_id, depth: depth)
          child.recalculate_subtree_depth!
        end
      else
        StrategyNode.where(id: descendant_ids).update_all(discarded_at: Time.current)
      end
      discard!
    end
  end

  def duplicate_branch!(actor: nil)
    mapping = {}
    transaction do
      copy = dup
      copy.assign_attributes(title: "#{title} (bản sao)", position: position + 512,
                             created_by: actor, updated_by: actor, children_count: 0, discarded_at: nil)
      copy.save!
      mapping[id] = copy
      queue = [self]
      until queue.empty?
        current = queue.shift
        current.children.each do |child|
          child_copy = child.dup
          child_copy.assign_attributes(parent_id: mapping[current.id].id, created_by: actor,
                                       updated_by: actor, children_count: 0, discarded_at: nil)
          child_copy.save!
          mapping[child.id] = child_copy
          queue << child
        end
      end
      mapping[id]
    end
  end

  def self.position_between(prev_pos, next_pos)
    prev_pos = prev_pos&.to_d
    next_pos = next_pos&.to_d
    return prev_pos + 1024 if next_pos.nil? && prev_pos
    return next_pos - 1024 if prev_pos.nil? && next_pos
    return 1024.to_d       if prev_pos.nil? && next_pos.nil?
    (prev_pos + next_pos) / 2
  end

  private

  def assign_depth
    self.depth = parent ? parent.depth + 1 : 0
  end

  def assign_position
    siblings = StrategyNode.kept.where(strategy_tree_id: strategy_tree_id, parent_id: parent_id)
    self.position = (siblings.maximum(:position) || 0) + 1024 if position.blank? || position.zero?
  end

  def depth_within_limit
    errors.add(:base, :too_deep) if depth.to_i > MAX_DEPTH
  end

  # BR-17 — chống vòng lặp.
  def parent_not_descendant
    return if parent_id.blank? || !persisted?
    errors.add(:parent_id, :cycle) if parent_id == id || descendant_ids.include?(parent_id)
  end
end
