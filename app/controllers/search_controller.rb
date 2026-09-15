class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    return if @q.blank?

    @projects = Project.kept.search_like(:name, :code, :client_name, term: @q).limit(10)
    @tasks    = Task.kept.includes(:project).search_like(:title, :code, term: @q).limit(15)
    @transactions = Transaction.kept.includes(:project, :category)
                               .search_like(:description, :counterparty, term: @q).newest.limit(10)
    @nodes    = StrategyNode.kept.includes(:strategy_tree).search_like(:title, term: @q).limit(10)
  end
end
