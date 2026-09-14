class ProjectTransactionsController < ApplicationController
  before_action :load_project

  def index
    @tab = "finance"
    @transactions = @project.transactions.kept.includes(:category, :created_by).newest.limit(300)
    @income  = @project.income_total
    @expense = @project.expense_total
    @monthly = Reporting::MonthlySeries.new(project: @project).call
  end

  private

  def load_project = @project = Project.kept.find_by!(code: params[:project_code])
end
