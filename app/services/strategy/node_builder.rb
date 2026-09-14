module Strategy
  # Chèn một cấu trúc lồng nhau [{title:, children:[]}] vào dưới một nút cha.
  class NodeBuilder
    Result = Struct.new(:created, :skipped_deep, keyword_init: true)

    def initialize(parent, actor:, ai_generated: false)
      @parent = parent
      @actor  = actor
      @ai     = ai_generated
    end

    def call(items)
      created = 0
      skipped = 0
      ActiveRecord::Base.transaction do
        created, skipped = insert(Array(items), @parent, created, skipped)
      end
      Result.new(created: created, skipped_deep: skipped)
    end

    private

    def insert(items, parent, created, skipped)
      items.each do |item|
        title = item[:title].presence || item["title"].presence
        next if title.blank?

        if parent.depth + 1 > StrategyNode::MAX_DEPTH
          skipped += 1
          next
        end

        node = parent.strategy_tree.strategy_nodes.create!(
          parent: parent, title: title.to_s.first(120),
          note: item[:note] || item["note"], status: :idea,
          created_by: @actor, updated_by: @actor, ai_generated: @ai
        )
        created += 1
        children = item[:children] || item["children"]
        created, skipped = insert(Array(children), node, created, skipped) if children.present?
      end
      [created, skipped]
    end
  end
end
