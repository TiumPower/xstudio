module StrategyTreesHelper
  # Toàn bộ cây được serialize một lần rồi giao cho Stimulus vẽ SVG —
  # tránh gọi DB theo từng cấp (mục 9.6).
  def tree_payload(entry)
    return nil if entry.nil?
    node = entry[:node]
    {
      id: node.id, parentId: node.parent_id, title: node.title, note: node.note.to_s,
      color: node.effective_color, ownColor: node.color, icon: node.icon.to_s,
      status: node.status, statusLabel: node.status_label, statusColor: node.status_color,
      ownerId: node.owner_id, ownerName: node.owner&.display_name,
      ownerInitials: node.owner&.initials, ownerColor: node.owner&.avatar_color,
      depth: node.depth, position: node.position.to_f,
      collapsed: node.collapsed, aiGenerated: node.ai_generated,
      updatedBy: node.updated_by&.display_name, updatedAt: time_ago(node.updated_at),
      children: entry[:children].map { |child| tree_payload(child) }
    }
  end
end
