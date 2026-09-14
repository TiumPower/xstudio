module Strategy
  # FR-TREE-44 — ảnh chụp phiên bản cây và khôi phục.
  class Snapshotter
    def initialize(tree)
      @tree = tree
    end

    def capture!(name:, auto: false, actor: nil)
      nodes = @tree.strategy_nodes.kept.order(:depth, :position, :id).map { |n| serialize(n) }
      @tree.strategy_snapshots.create!(
        name: name, payload: { nodes: nodes }, node_count: nodes.size,
        auto: auto, created_by: actor, created_at: Time.current
      )
    end

    # BR-23 — chụp lại trạng thái hiện tại TRƯỚC khi ghi đè, để luôn quay lại được.
    def restore!(snapshot, actor: nil)
      ActiveRecord::Base.transaction do
        capture!(name: "Trước khi khôi phục “#{snapshot.name}”", auto: true, actor: actor)

        @tree.strategy_nodes.delete_all
        mapping = {}
        Array(snapshot.payload["nodes"] || snapshot.payload[:nodes]).each do |attrs|
          attrs = attrs.with_indifferent_access
          node = @tree.strategy_nodes.create!(
            title: attrs[:title], note: attrs[:note], color: attrs[:color], icon: attrs[:icon],
            status: attrs[:status], owner_id: attrs[:owner_id], position: attrs[:position],
            depth: attrs[:depth], collapsed: attrs[:collapsed], ai_generated: attrs[:ai_generated],
            parent_id: attrs[:parent_id] ? mapping[attrs[:parent_id]] : nil,
            created_by: actor, updated_by: actor
          )
          mapping[attrs[:id]] = node.id
        end
        StrategyNode.where(id: mapping.values).find_each { |n| StrategyNode.reset_counters(n.id, :children) rescue nil }
      end
      true
    end

    private

    def serialize(node)
      {
        id: node.id, parent_id: node.parent_id, title: node.title, note: node.note,
        color: node.color, icon: node.icon, status: node.status, owner_id: node.owner_id,
        position: node.position.to_f, depth: node.depth, collapsed: node.collapsed,
        ai_generated: node.ai_generated
      }
    end
  end
end
