class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    return if @q.blank?

    like = "%#{@q}%"
    @projects = Project.kept.where("name ILIKE :q OR code ILIKE :q OR client_name ILIKE :q", q: like).limit(10)
    @tasks    = Task.kept.includes(:project).where("title ILIKE :q OR code ILIKE :q", q: like).limit(15)
    @transactions = Transaction.kept.includes(:project, :category)
                               .where("description ILIKE :q OR counterparty ILIKE :q", q: like).newest.limit(10)
    @nodes    = StrategyNode.kept.includes(:strategy_tree).where("title ILIKE :q", q: like).limit(10)
  end
end
