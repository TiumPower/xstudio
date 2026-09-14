require "csv"

module Finance
  # FR-FIN-09 — xuất sổ thu chi. BOM để Excel mở đúng dấu tiếng Việt.
  class CsvExport
    HEADERS = ["Ngày", "Loại", "Số tiền (₫)", "Danh mục", "Thuộc về",
               "Diễn giải", "Đối tác", "Phương thức", "Người tạo"].freeze

    def initialize(transactions)
      @transactions = transactions
    end

    def call
      csv = CSV.generate do |out|
        out << HEADERS
        @transactions.each { |t| out << row(t) }
        out << []
        out << ["Tổng thu", nil, total(:income)]
        out << ["Tổng chi", nil, total(:expense)]
        out << ["Chênh lệch", nil, total(:income) - total(:expense)]
      end
      "﻿#{csv}"
    end

    private

    def row(t)
      [
        I18n.l(t.occurred_on),
        t.kind_label,
        t.amount,
        t.category&.name,
        t.project ? "#{t.project.code} · #{t.project.name}" : "Chung workspace",
        t.description,
        t.counterparty,
        I18n.t("payment_methods.#{t.payment_method}"),
        t.created_by&.display_name
      ]
    end

    def total(kind)
      @totals ||= {}
      @totals[kind] ||= @transactions.select { |t| t.kind == kind.to_s }.sum(&:amount)
    end
  end
end
