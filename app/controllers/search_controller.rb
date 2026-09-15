class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    return if @q.blank?

    @projects = visible_projects.search_like(:name, :code, :client_name, term: @q).limit(10)
    @tasks    = Task.kept.where(project_id: visible_project_ids)
                    .includes(:project).search_like(:title, :code, term: @q).limit(15)
    @transactions = Transaction.kept.where(project_id: [nil, *visible_project_ids])
                               .includes(:project, :category)
                               .search_like(:description, :counterparty, term: @q).newest.limit(10)
    @nodes    = StrategyNode.kept.includes(:strategy_tree).search_like(:title, term: @q).limit(10)
  end
end
