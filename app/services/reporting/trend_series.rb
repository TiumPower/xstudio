module Reporting
  # Chuỗi Thu — Chi bám theo kỳ đang chọn trên Tổng quan.
  #
  # Mức chia tự đổi theo độ dài kỳ, để số cột luôn đọc được:
  #   ≤ 31 ngày  → theo ngày   (Tháng này)
  #   ≤ 120 ngày → theo tuần   (Quý này)
  #   dài hơn    → theo tháng  (Năm nay, kỳ tuỳ chọn dài)
  class TrendSeries
    Result = Struct.new(:points, :unit, :caption, keyword_init: true)

    # Khoá `step` phải ở dạng SỐ NHIỀU: Date#advance nhận :days/:weeks/:months.
    # Dùng số ít thì advance không cộng gì cả và vòng lặp dựng mốc chạy vô hạn.
    UNITS = {
      day:   { trunc: "day",   step: :days,   caption: "theo ngày" },
      week:  { trunc: "week",  step: :weeks,  caption: "theo tuần" },
      month: { trunc: "month", step: :months, caption: "theo tháng" }
    }.freeze

    def initialize(range:, project: nil, project_type: nil)
      @range = range
      @project = project
      @project_type = project_type
    end

    def call
      unit = pick_unit
      conf = UNITS[unit]
      sums = totals(conf[:trunc])

      points = buckets(unit).map do |start|
        income  = pick(sums, "income",  start)
        expense = pick(sums, "expense", start)
        { at: start, label: label_for(start, unit),
          income: income, expense: expense, profit: income - expense }
      end

      Result.new(points: points, unit: unit, caption: conf[:caption])
    end

    private

    def days = @days ||= (@range.last - @range.first).to_i + 1

    def pick_unit
      return :day   if days <= 31
      return :week  if days <= 120
      :month
    end

    def totals(trunc)
      scope = Transaction.kept.where(occurred_on: @range)
      scope = scope.where(project_id: @project.id) if @project
      scope = scope.joins(:project).where(projects: { project_type: @project_type }) if @project_type
      scope.group(:kind, Arel.sql("date_trunc('#{trunc}', occurred_on)")).sum(:amount)
    end

    def buckets(unit)
      first = truncate(@range.first, unit)
      last  = truncate(@range.last, unit)
      out   = []
      cursor = first
      while cursor <= last
        out << cursor
        cursor = cursor.advance(UNITS[unit][:step] => 1)
      end
      out
    end

    def truncate(date, unit)
      case unit
      when :day   then date
      when :week  then date.beginning_of_week
      else date.beginning_of_month
      end
    end

    # Nhãn trục X. Chia theo ngày thì chỉ cần số ngày — kỳ đã ghi rõ ở tiêu đề
    # nên không phải lặp lại tháng ở từng cột.
    def label_for(date, unit)
      case unit
      when :day   then date.day.to_s
      when :week  then date.strftime("%d/%m")
      else date.strftime("%m/%y")
      end
    end

    # group() trả về khoá là chuỗi hoặc số tuỳ enum, nên dò cả hai kiểu.
    def pick(sums, kind, bucket)
      index = Transaction.kinds[kind]
      sums.find { |(k, at), _| (k.to_s == kind || k == index) && at.to_date == bucket }&.last || 0
    end
  end
end
