module Strategy
  # FR-TREE-20..28 — AI gợi ý nhánh con / dựng cả cây con từ một chủ đề.
  #
  # Nguyên tắc bắt buộc (mục 9.8): CHỈ gửi tiêu đề nút và đường dẫn nhánh.
  # Không bao giờ gửi dữ liệu tài chính hay thông tin khách hàng vào prompt.
  class Suggester
    Result = Struct.new(:suggestions, :error, :duration_ms, keyword_init: true) do
      def ok? = error.nil?
    end

    SYSTEM = <<~TXT.freeze
      Bạn là trợ lý hoạch định chiến lược cho một đội phát triển & tư vấn phần mềm Việt Nam.
      Đội hoạt động trên hai mảng: (1) tự xây sản phẩm và tự đi bán,
      (2) tư vấn & triển khai chuyển đổi số cho khách hàng, trọng tâm dữ liệu và AI.

      Nhiệm vụ: đề xuất các nhánh con cụ thể, hành động được, cho một nút trong cây định hướng.
      Quy tắc:
      - Viết hoàn toàn bằng tiếng Việt tự nhiên, không chèn tiếng Anh trừ thuật ngữ đã quen (AI, SaaS, ETL…).
      - Mỗi tiêu đề tối đa 60 ký tự, là một danh từ/cụm danh từ, không phải câu.
      - Giải thích (reason) đúng MỘT dòng, tối đa 120 ký tự.
      - Tuyệt đối không lặp lại các nhánh con đã có.
      - Không đề xuất chung chung kiểu "Nghiên cứu thêm", "Cải thiện quy trình".
    TXT

    def initialize(node:, instruction: nil, mode: :children)
      @node = node
      @instruction = instruction.to_s.strip.first(400)
      @mode = mode.to_sym
    end

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return Result.new(error: :not_configured) unless ClaudeService.configured?

      raw = ClaudeService.new(model: ClaudeService::SONNET, max_tokens: 1600).json(prompt, system: SYSTEM)
      list = normalize(raw)
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      return Result.new(error: :empty, duration_ms: elapsed) if list.empty?
      Result.new(suggestions: list, duration_ms: elapsed)
    rescue ClaudeService::Error => e
      Rails.logger.error("[Strategy::Suggester] #{e.message}")
      Result.new(error: :api_error, duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
    end

    private

    def existing_titles = @existing_titles ||= @node.children.pluck(:title)

    def prompt
      path = @node.path_titles.join(" → ")
      base = +"Cây định hướng: #{@node.strategy_tree.name}\n"
      base << "Đường dẫn từ gốc: #{path}\n"
      base << "Nút hiện tại: #{@node.title}\n"
      base << "Ghi chú của nút: #{@node.note.to_s.truncate(300)}\n" if @node.note.present?
      base << "Các nhánh con ĐÃ CÓ (không được trùng, không được diễn đạt lại): #{existing_titles.join(' | ')}\n" if existing_titles.any?
      base << "Chỉ dẫn thêm của người dùng: #{@instruction}\n" if @instruction.present?
      base << "Còn tối đa #{StrategyNode::MAX_DEPTH - @node.depth} cấp bên dưới nút này.\n\n"

      if @mode == :subtree
        base << <<~TXT
          Hãy dựng bản nháp cây con 2 cấp dưới nút này: 4–6 nhánh lớn, mỗi nhánh 2–4 nhánh nhỏ.
          Trả về JSON đúng cấu trúc:
          {"suggestions":[{"title":"...","reason":"...","children":[{"title":"...","reason":"..."}]}]}
        TXT
      else
        base << <<~TXT
          Hãy đề xuất 5–8 nhánh con cho nút hiện tại.
          Trả về JSON đúng cấu trúc:
          {"suggestions":[{"title":"...","reason":"..."}]}
        TXT
      end
      base
    end

    # FR-TREE-23 — lọc lại kết quả, loại bỏ trùng với nút con đang có.
    def normalize(raw)
      items = raw.is_a?(Hash) ? (raw["suggestions"] || raw[:suggestions]) : raw
      seen  = existing_titles.map { |t| key(t) }

      Array(items).filter_map do |item|
        item = item.with_indifferent_access rescue next
        title = item[:title].to_s.strip.first(120)
        next if title.blank? || seen.include?(key(title))
        seen << key(title)

        children = Array(item[:children]).filter_map do |c|
          c = c.with_indifferent_access rescue next
          ct = c[:title].to_s.strip.first(120)
          next if ct.blank?
          { "title" => ct, "reason" => c[:reason].to_s.strip.first(160) }
        end

        { "title" => title, "reason" => item[:reason].to_s.strip.first(160), "children" => children }
      end.first(@mode == :subtree ? 6 : 8)
    end

    def key(title) = title.to_s.downcase.gsub(/[^\p{L}\p{N}]/, "")
  end
end
