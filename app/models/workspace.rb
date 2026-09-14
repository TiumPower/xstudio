# Cấu hình không gian làm việc — hệ thống chỉ có đúng 1 bản ghi (FR-WS-01).
class Workspace < ApplicationRecord
  has_one_attached :logo

  validates :name, presence: true

  # Bản ghi đơn. Tạo lười để app chạy được ngay sau khi migrate.
  def self.current
    first || create!(name: "Team Workspace")
  end
end
