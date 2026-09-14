class StrategyNodesController < ApplicationController
  before_action :load_tree
  before_action :load_node, only: [:update, :destroy, :move, :duplicate, :suggest, :apply_suggestions]

  def create
    parent = @tree.strategy_nodes.kept.find(params[:parent_id])
    if parent.depth + 1 > StrategyNode::MAX_DEPTH
      return render_error("Đã đạt giới hạn #{StrategyNode::MAX_DEPTH} cấp. Không thể thêm nút con ở đây.")
    end

    @node = @tree.strategy_nodes.new(node_params)
    @node.parent     = parent
    @node.title      = @node.title.presence || "Nút mới"
    @node.created_by = current_user
    @node.updated_by = current_user
    @node.position   = StrategyNode.position_between(params[:prev_position], params[:next_position]) if params[:prev_position] || params[:next_position]

    if @node.save
      log_activity("node_created", trackable: @node, summary: "đã thêm nút “#{@node.title}” vào #{@tree.name}")
      render_tree(notice: nil)
    else
      render_error(@node.errors.full_messages.to_sentence)
    end
  end

  def update
    @node.updated_by = current_user
    if @node.update(node_params)
      log_activity("node_updated", trackable: @node, summary: "đã sửa nút “#{@node.title}”")
      render_tree
    else
      render_error(@node.errors.full_messages.to_sentence)
    end
  end

  # FR-TREE-13/14 — kéo–thả đổi cha và đổi thứ tự.
  def move
    new_parent = params[:parent_id].present? ? @tree.strategy_nodes.kept.find(params[:parent_id]) : nil
    return render_error("Không thể xoá nút gốc khỏi cây.") if @node.root?

    @node.move_to!(new_parent: new_parent,
                   prev_position: params[:prev_position], next_position: params[:next_position])
    @node.update_column(:updated_by_id, current_user.id)
    log_activity("node_moved", trackable: @node,
                 summary: "đã di chuyển nút “#{@node.title}” trong #{@tree.name}")
    render_tree
  rescue ArgumentError => e
    message = e.message == "too_deep" ? "Không thả được: nhánh này sẽ vượt quá #{StrategyNode::MAX_DEPTH} cấp." :
                                        "Không thả được: không thể đặt một nút vào chính nhánh con của nó."
    render_error(message)
  end

  # FR-TREE-17 — xoá cả nhánh hoặc đẩy con lên cấp trên.
  def destroy
    return render_error("Không xoá được nút gốc.") if @node.root?

    mode = params[:mode].to_s == "promote" ? :promote : :cascade
    count = @node.descendants_count
    @node.discard_branch!(mode: mode)
    log_activity("node_deleted", trackable: @node,
                 summary: "đã xoá nút “#{@node.title}”#{mode == :cascade && count.positive? ? " và #{count} nút con" : ''}")
    render_tree
  end

  def duplicate
    return render_error("Không nhân bản được nút gốc.") if @node.root?
    copy = @node.duplicate_branch!(actor: current_user)
    log_activity("node_created", trackable: copy, summary: "đã nhân bản nút “#{@node.title}”")
    render_tree
  end

  # FR-TREE-12 — dán hàng loạt văn bản thụt lề.
  def bulk_paste
    parent = @tree.strategy_nodes.kept.find(params[:parent_id])
    items  = Strategy::OutlineParser.new(params[:text], max_depth: StrategyNode::MAX_DEPTH - parent.depth).call

    if params[:preview].present?
      render json: { items: items, count: count_items(items) }
      return
    end
    return render_error("Không nhận ra cấu trúc nào trong nội dung đã dán.") if items.empty?

    result = Strategy::NodeBuilder.new(parent, actor: current_user).call(items)
    log_activity("node_created", trackable: parent,
                 summary: "đã dán #{result.created} nút vào “#{parent.title}”")
    notice = "Đã thêm #{result.created} nút."
    notice += " Bỏ qua #{result.skipped_deep} nút vượt quá #{StrategyNode::MAX_DEPTH} cấp." if result.skipped_deep.positive?
    render_tree(notice: notice)
  end

  # ---- ✨ AI ------------------------------------------------------------
  def suggest
    unless ClaudeService.configured?
      return render json: { error: "Chưa cấu hình khoá AI. Liên hệ quản trị viên." }, status: :service_unavailable
    end
    if AiSuggestionLog.remaining_today(current_user) <= 0
      return render json: { error: "Bạn đã dùng hết #{AiSuggestionLog::DAILY_LIMIT} lượt gợi ý hôm nay. Hạn mức đặt lại lúc 00:00." },
                    status: :too_many_requests
    end

    mode   = params[:mode].to_s == "subtree" ? :subtree : :children
    result = Strategy::Suggester.new(node: @node, instruction: params[:instruction], mode: mode).call

    log = AiSuggestionLog.create!(
      user: current_user, strategy_node: @node, mode: mode,
      instruction: params[:instruction].to_s.first(1000),
      suggestions: { items: result.suggestions || [] },
      status: result.ok? ? :success : :failed,
      duration_ms: result.duration_ms
    )

    unless result.ok?
      message = { not_configured: "Chưa cấu hình khoá AI.",
                  empty:  "AI không đưa ra được gợi ý nào. Thử thêm chỉ dẫn cụ thể hơn.",
                  api_error: "Không gọi được AI lúc này (mạng hoặc quá tải). Cây của bạn không thay đổi." }[result.error]
      return render json: { error: message }, status: :bad_gateway
    end

    render json: {
      log_id: log.id, mode: mode,
      remaining: AiSuggestionLog.remaining_today(current_user),
      suggestions: result.suggestions
    }
  end

  # FR-TREE-22 — chỉ chèn những gợi ý người dùng đã tick.
  def apply_suggestions
    items = Array(params[:items]).map do |item|
      item = item.permit!.to_h if item.respond_to?(:permit!)
      { title: item["title"], note: item["reason"].presence,
        children: Array(item["children"]).map { |c| { title: c["title"], note: c["reason"].presence } } }
    end.select { |i| i[:title].present? }

    return render_error("Chưa chọn gợi ý nào.") if items.empty?

    result = Strategy::NodeBuilder.new(@node, actor: current_user, ai_generated: true).call(items)
    if params[:log_id].present?
      AiSuggestionLog.where(id: params[:log_id], user_id: current_user.id)
                     .update_all(accepted_count: result.created)
    end
    log_activity("node_created", trackable: @node,
                 summary: "đã thêm #{result.created} nút từ gợi ý AI vào “#{@node.title}”")
    render_tree(notice: "Đã thêm #{result.created} nút vào cây.")
  end

  private

  def load_tree = @tree = StrategyTree.kept.find_by!(slug: params[:strategy_tree_slug])
  def load_node = @node = @tree.strategy_nodes.kept.find(params[:id])

  def node_params
    params.require(:strategy_node).permit(:title, :note, :color, :icon, :status, :owner_id, :collapsed)
  end

  def count_items(items)
    Array(items).sum { |i| 1 + count_items(i[:children] || i["children"]) }
  end

  def render_tree(notice: nil)
    flash[:notice] = notice if notice.present?
    respond_to do |format|
      format.json { render json: { ok: true, notice: notice } }
      format.html { redirect_to strategy_tree_path(@tree) }
      format.turbo_stream { redirect_to strategy_tree_path(@tree) }
    end
  end

  def render_error(message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html { redirect_to strategy_tree_path(@tree), alert: message }
      format.turbo_stream { redirect_to strategy_tree_path(@tree), alert: message }
    end
  end
end
