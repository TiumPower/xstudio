class EnableUnaccent < ActiveRecord::Migration[7.2]
  # Người Việt gõ không dấu là chuyện thường: "chuye" phải ra "Chuyển đổi số".
  # unaccent() bỏ dấu ở cả cột lẫn từ khoá nên so khớp mới đúng.
  def up   = enable_extension("unaccent")
  def down = disable_extension("unaccent")
end
