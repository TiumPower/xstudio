module Finance
  # Tổng thu/chi cho nhiều dự án bằng 1 truy vấn gộp (tránh N+1 — mục 9.3).
  class ProjectTotals
    def initialize(project_ids)
      @project_ids = Array(project_ids).compact.uniq
    end

    def call
      return {} if @project_ids.empty?
      rows = Transaction.kept.where(project_id: @project_ids).group(:project_id, :kind).sum(:amount)

      @project_ids.index_with do |pid|
        income  = rows[[pid, "income"]]  || rows[[pid, 0]] || 0
        expense = rows[[pid, "expense"]] || rows[[pid, 1]] || 0
        { income: income, expense: expense, profit: income - expense }
      end
    end
  end
end
