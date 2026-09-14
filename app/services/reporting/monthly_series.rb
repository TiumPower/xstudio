module Reporting
  # Chuỗi thu — chi theo tháng (FR-DASH-02, FR-PRJ tab Thu chi).
  class MonthlySeries
    def initialize(project: nil, months: 12, project_type: nil)
      @project = project
      @months  = months
      @project_type = project_type
    end

    def call
      first = (@months - 1).months.ago.beginning_of_month.to_date
      scope = Transaction.kept.where("occurred_on >= ?", first)
      scope = scope.where(project_id: @project.id) if @project
      scope = scope.joins(:project).where(projects: { project_type: @project_type }) if @project_type

      sums = scope.group(:kind, Arel.sql("date_trunc('month', occurred_on)")).sum(:amount)

      (0...@months).map do |i|
        month = (first + i.months).beginning_of_month
        key   = month.to_time
        income  = pick(sums, "income",  key)
        expense = pick(sums, "expense", key)
        { month: month, label: month.strftime("%m/%y"), income: income, expense: expense, profit: income - expense }
      end
    end

    private

    def pick(sums, kind, key)
      sums.find { |(k, m), _| k.to_s == kind && m.to_date == key.to_date }&.last ||
        sums.find { |(k, m), _| k.to_s == Transaction.kinds[kind].to_s && m.to_date == key.to_date }&.last || 0
    end
  end
end
