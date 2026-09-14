module Strategy
  # FR-TREE-12 — dán hàng loạt: văn bản thụt lề (tab, 2–4 dấu cách, -/* markdown)
  # → cấu trúc cây lồng nhau. Trả về mảng {title:, children:[]}.
  class OutlineParser
    MAX_LINES = 400

    def initialize(text, max_depth: StrategyNode::MAX_DEPTH)
      @text = text.to_s
      @max_depth = max_depth
    end

    def call
      rows = parse_rows
      return [] if rows.empty?

      # Chuẩn hoá các mức thụt lề thô về 0,1,2… theo thứ tự xuất hiện.
      levels = rows.map { |r| r[:indent] }.uniq.sort
      root   = { children: [] }
      stack  = [root]

      rows.each do |row|
        depth = [levels.index(row[:indent]), @max_depth - 1].min
        stack  = stack.first(depth + 1)
        stack << stack.last[:children].last if stack.length <= depth && stack.last[:children].any?
        parent = stack[depth] || stack.last
        node   = { title: row[:title], children: [] }
        parent[:children] << node
        stack[depth + 1] = node
      end
      root[:children]
    end

    private

    def parse_rows
      @text.lines.first(MAX_LINES).filter_map do |line|
        next if line.strip.empty?
        raw    = line.rstrip
        indent = raw[/\A[\t ]*/].to_s.gsub("\t", "  ").length
        title  = raw.strip.sub(/\A[-*•+]\s*/, "").sub(/\A\d+[.)]\s*/, "").strip
        next if title.empty?
        { indent: indent, title: title.first(120) }
      end
    end
  end
end
