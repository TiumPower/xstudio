module Reporting
  # Toàn bộ số liệu cho trang Tổng quan (mục 3.8), gom bằng truy vấn tổng hợp.
  class Dashboard
    Result = Struct.new(:financial, :monthly, :expense_breakdown, :by_project_type,
                        :top_projects, :worst_projects, :project_stats, :project_rows,
                        :workload, :my_tasks, :recent_activities, keyword_init: true)

    def initialize(range:, project_type: nil, user:)
      @range = range
      @type  = project_type.presence
      @user  = user
    end

    def call
      Result.new(
        financial:         financial,
        monthly:           MonthlySeries.new(months: 12, project_type: @type).call,
        expense_breakdown: expense_breakdown,
        by_project_type:   by_project_type,
        top_projects:      profit_ranking.first(5),
        worst_projects:    profit_ranking.reverse.select { |r| r[:profit].negative? }.first(5),
        project_stats:     project_stats,
        project_rows:      project_rows,
        workload:          workload,
        my_tasks:          my_tasks,
        recent_activities: Activity.newest.includes(:user, :project).limit(10)
      )
    end

    private

    def scoped_transactions(range = @range)
      scope = Transaction.kept.in_period(range.first, range.last)
      @type ? scope.joins(:project).where(projects: { project_type: @type }) : scope
    end

    def financial
      current  = scoped_transactions.group(:kind).sum(:amount)
      previous = scoped_transactions(previous_range).group(:kind).sum(:amount)

      income  = fetch(current, :income)
      expense = fetch(current, :expense)

      # Tổng chi ở đây là chi của MỌI dự án cộng chi chung workspace — trang
      # Tổng quan nhìn cả đội nên không tách riêng.
      {
        income:  { value: income,  previous: fetch(previous, :income) },
        expense: { value: expense, previous: fetch(previous, :expense) },
        profit:  { value: income - expense, previous: fetch(previous, :income) - fetch(previous, :expense) }
      }
    end

    def previous_range
      span = (@range.last - @range.first).to_i + 1
      (@range.first - span)..(@range.first - 1)
    end

    def fetch(hash, kind)
      hash[kind.to_s] || hash[Transaction.kinds[kind]] || 0
    end

    # FR-DASH-03 — cơ cấu chi theo danh mục.
    def expense_breakdown
      sums  = scoped_transactions.expense.group(:category_id).sum(:amount)
      total = sums.values.sum
      names = TransactionCategory.where(id: sums.keys.compact).pluck(:id, :name).to_h

      sums.sort_by { |_, v| -v }.map do |cat_id, amount|
        { name: names[cat_id] || "Chưa phân loại", amount: amount,
          percent: total.zero? ? 0 : (amount.to_f / total * 100).round }
      end
    end

    # FR-DASH-04 — thu chi theo loại hình dự án.
    def by_project_type
      rows = Transaction.kept.in_period(@range.first, @range.last)
                        .joins(:project).group("projects.project_type", :kind).sum(:amount)

      Project.project_types.keys.map do |type|
        idx    = Project.project_types[type]
        income  = rows[[idx, "income"]]  || rows[[type, "income"]]  || rows[[idx, 0]] || 0
        expense = rows[[idx, "expense"]] || rows[[type, "expense"]] || rows[[idx, 1]] || 0
        { type: type, label: I18n.t("project_types.#{type}"), income: income, expense: expense, profit: income - expense }
      end
    end

    def projects_scope
      scope = Project.kept.includes(:owner)
      @type ? scope.where(project_type: @type) : scope
    end

    def totals_by_project
      @totals_by_project ||= Finance::ProjectTotals.new(projects_scope.pluck(:id)).call
    end

    def profit_ranking
      @profit_ranking ||= projects_scope.map do |p|
        t = totals_by_project[p.id] || { income: 0, expense: 0, profit: 0 }
        { project: p, income: t[:income], expense: t[:expense], profit: t[:profit] }
      end.sort_by { |r| -r[:profit] }
    end

    # FR-DASH-06 — hàng chỉ số dự án.
    def project_stats
      all = projects_scope.where(archived_at: nil)
      {
        in_progress: all.count { |p| p.status_in_progress? },
        overdue:     all.count(&:overdue?),
        completed:   all.count { |p| p.status_completed? && p.completed_at && @range.cover?(p.completed_at.to_date) },
        open_tasks:  Task.kept.open_tasks.where(project_id: all.map(&:id)).count
      }
    end

    # FR-DASH-07 — bảng tình trạng dự án.
    def project_rows
      projects_scope.where(archived_at: nil).open_status.recent.limit(12).map do |p|
        t = totals_by_project[p.id] || { income: 0, expense: 0, profit: 0 }
        { project: p, progress: p.progress, income: t[:income], expense: t[:expense], profit: t[:profit] }
      end
    end

    # FR-DASH-08 — phân bổ công việc theo người.
    def workload
      counts = Task.kept.where.not(status: Task.statuses[:cancelled])
                   .where.not(assignee_id: nil).group(:assignee_id, :status).count
      users  = User.where(id: counts.keys.map(&:first).uniq).index_by(&:id)

      users.values.map do |user|
        open = counts[[user.id, "open"]] || counts[[user.id, 0]] || 0
        done = counts[[user.id, "done"]] || counts[[user.id, 1]] || 0
        overdue = Task.kept.open_tasks.where(assignee_id: user.id).where("due_date < ?", Date.current).count
        { user: user, open: open, done: done, overdue: overdue, total: open + done }
      end.sort_by { |r| -r[:open] }.first(10)
    end

    # FR-DASH-09 — widget Việc của tôi.
    def my_tasks
      scope = Task.kept.open_tasks.where(assignee_id: @user.id)
      {
        overdue:   scope.where("due_date < ?", Date.current).count,
        today:     scope.where(due_date: Date.current).count,
        this_week: scope.where(due_date: Date.current..Date.current.end_of_week).count,
        recent:    scope.includes(:project).order(Arel.sql("due_date NULLS LAST")).limit(5).to_a
      }
    end
  end
end
