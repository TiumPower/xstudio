class AddContentToProjectResources < ActiveRecord::Migration[7.2]
  # Tài liệu giờ có hai dạng: tải tệp lên như cũ, hoặc viết thẳng trong app
  # bằng Markdown / HTML. Cột `content` giữ bản gốc người dùng gõ; HTML hiển
  # thị được dựng lại và lọc mỗi lần đọc, không lưu sẵn — để đổi bộ lọc là
  # mọi tài liệu cũ được áp dụng ngay.
  def change
    add_column :project_resources, :content, :text
    add_column :project_resources, :content_format, :integer, null: false, default: 0
  end
end
