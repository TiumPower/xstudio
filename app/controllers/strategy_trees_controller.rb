class StrategyTreesController < ApplicationController
  before_action :load_tree, only: [:show, :update, :destroy, :export_markdown]

  def index
    tree = StrategyTree.ordered.first || bootstrap_first_tree
    redirect_to strategy_tree_path(tree)
  end

  def show
    @trees   = StrategyTree.ordered.to_a
    @view    = params[:view].presence_in(%w[mindmap vertical outline]) || cookies[:strategy_view].presence || "mindmap"
    cookies[:strategy_view] = { value: @view, expires: 1.year.from_now }
    @max_level = (params[:level].presence || 3).to_i.clamp(1, StrategyNode::MAX_DEPTH)
    @tree_data = @tree.nodes_tree
    @members   = User.assignable
    @ai_remaining = AiSuggestionLog.remaining_today(current_user)
    @ai_enabled   = ClaudeService.configured?
  end

  def new
    @tree = StrategyTree.new
  end

  def create
    @tree = StrategyTree.new(tree_params.merge(created_by: current_user))
    if @tree.save
      seed_from_template(@tree) if params[:template].present?
      log_activity("created", trackable: @tree, summary: "đã tạo cây định hướng #{@tree.name}")
      redirect_to strategy_tree_path(@tree), notice: "Đã tạo cây “#{@tree.name}”."
    else
      redirect_to strategy_trees_path, alert: @tree.errors.full_messages.to_sentence
    end
  end

  def update
    if @tree.update(tree_params)
      redirect_to strategy_tree_path(@tree), notice: "Đã lưu."
    else
      redirect_to strategy_tree_path(@tree), alert: @tree.errors.full_messages.to_sentence
    end
  end

  def destroy
    if StrategyTree.kept.count <= 1
      redirect_to strategy_tree_path(@tree), alert: "Phải giữ ít nhất một cây định hướng."
      return
    end
    @tree.discard
    log_activity("deleted", trackable: @tree, summary: "đã xoá cây định hướng #{@tree.name}")
    redirect_to strategy_trees_path, notice: "Đã xoá cây “#{@tree.name}”."
  end

  # FR-TREE-37 — xuất Markdown outline.
  def export_markdown
    lines = []
    walk  = lambda do |entry, level|
      node = entry[:node]
      prefix = level.zero? ? "# " : "#{'  ' * (level - 1)}- "
      suffix = node.status_idea? ? "" : " _(#{node.status_label})_"
      lines << "#{prefix}#{node.icon.presence&.+(' ')}#{node.title}#{suffix}"
      entry[:children].each { |c| walk.call(c, level + 1) }
    end
    data = @tree.nodes_tree
    walk.call(data, 0) if data

    send_data "#{lines.join("\n")}\n",
              filename: "#{@tree.slug}.md", type: "text/markdown; charset=utf-8"
  end

  private

  def load_tree = @tree = StrategyTree.kept.find_by!(slug: params[:slug])
  def tree_params = params.require(:strategy_tree).permit(:name, :description)

  def bootstrap_first_tree
    StrategyTree.create!(name: "Định hướng #{current_workspace.name}", created_by: current_user)
  end

  TEMPLATES = {
    "year" => ["Products", "Chuyển đổi số (Data & AI)", "Năng lực nội bộ", "Tài chính & Vận hành"],
    "product" => ["Khám phá khách hàng", "Sản phẩm lõi", "Kênh bán", "Hỗ trợ & Vận hành"],
    "blank" => []
  }.freeze

  def seed_from_template(tree)
    titles = TEMPLATES[params[:template]] || []
    return if titles.empty?
    root = tree.root
    titles.each { |t| tree.strategy_nodes.create!(parent: root, title: t, status: :idea, created_by: current_user, updated_by: current_user) }
  end
end
