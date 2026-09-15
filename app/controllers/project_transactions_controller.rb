class ProjectTransactionsController < ApplicationController
  before_action :load_project

  def index
    @tab = "finance"
    @pagy         = Pagination.new(@project.transactions.kept.includes(:category, :created_by).newest, page: params[:page])
    @transactions = @pagy.records
    @income  = @project.income_total
    @expense = @project.expense_total
    @monthly = Reporting::MonthlySeries.new(project: @project).call

    # Cơ cấu chi theo danh mục — thứ dải chỉ số ở đầu trang không nói được.
    sums   = @project.transactions.kept.expense.group(:category_id).sum(:amount)
    names  = TransactionCategory.where(id: sums.keys.compact).pluck(:id, :name).to_h
    @by_category = sums.sort_by { |_, v| -v }.map do |cat_id, amount|
      { name: names[cat_id] || "Chưa phân loại", amount: amount,
        percent: @expense.zero? ? 0 : (amount.to_f / @expense * 100).round }
    end
  end

  private

  def load_project = @project = Project.kept.find_by!(code: params[:project_code])
end
