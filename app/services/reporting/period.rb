module Reporting
  # Bộ lọc kỳ trên Tổng quan: Tháng này · Quý này · Năm nay · Tuỳ chọn.
  class Period
    LABELS = { "month" => "Tháng này", "quarter" => "Quý này", "year" => "Năm nay", "custom" => "Tuỳ chọn" }.freeze

    def initialize(key, from = nil, to = nil)
      @key  = key.to_s
      @from = parse(from)
      @to   = parse(to)
    end

    def range
      case @key
      when "quarter" then Date.current.beginning_of_quarter..Date.current.end_of_quarter
      when "year"    then Date.current.beginning_of_year..Date.current.end_of_year
      when "custom"  then (@from || Date.current.beginning_of_month)..(@to || Date.current)
      else Date.current.beginning_of_month..Date.current.end_of_month
      end
    end

    # Kỳ liền trước, cùng độ dài — dùng cho % so với kỳ trước.
    def previous_range
      r    = range
      span = (r.last - r.first).to_i + 1
      (r.first - span)..(r.first - 1)
    end

    def label = LABELS[@key] || LABELS["month"]

    private

    def parse(value) = value.present? ? (Date.parse(value) rescue nil) : nil
  end
end
