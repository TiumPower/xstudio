# Cấu hình không gian làm việc — hệ thống chỉ có đúng 1 bản ghi (FR-WS-01).
class Workspace < ApplicationRecord
  has_one_attached :logo

  validates :name, presence: true
  validate  :logo_is_an_image

  # Bản ghi đơn. Tạo lười để app chạy được ngay sau khi migrate.
  def self.current
    first || create!(name: "Team Workspace")
  end

  private

  # Logo nằm trên thanh bên của mọi trang: một tệp không phải ảnh lọt vào là
  # thẻ <img> hỏng ở khắp nơi, mà lúc tải lên không ai biết.
  def logo_is_an_image
    return unless logo.attached?
    return if logo.blob.blank? || Attachments::IMAGE_TYPES.include?(logo.blob.content_type)
    errors.add(:logo, "phải là ảnh (PNG, JPG, GIF, WEBP, SVG).")
  end
end
