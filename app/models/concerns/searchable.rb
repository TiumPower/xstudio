# Tìm kiếm không phân biệt dấu và hoa thường.
#
# `unaccent()` bỏ dấu tiếng Việt ở cả hai vế, nên gõ "chuye" vẫn ra
# "Chuyển đổi số" — đúng thói quen gõ của người dùng.
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    # search_like(:name, :code, term: "chuye")
    def search_like(*columns, term:)
      return all if term.blank?

      qualified = columns.map { |c| "unaccent(#{table_name}.#{c})" }
      clause    = qualified.map { |c| "#{c} ILIKE unaccent(:q)" }.join(" OR ")
      where(clause, q: "%#{term.to_s.strip}%")
    end
  end
end
