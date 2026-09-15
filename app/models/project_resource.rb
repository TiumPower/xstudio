class ProjectResource < ApplicationRecord
  # Ba loại tài nguyên của một sản phẩm:
  #   link    — trang web, kho mã, bảng thiết kế…
  #   account — ghi lại DÙNG TÀI KHOẢN NÀO để truy cập (email/tên đăng nhập).
  #             Không lưu mật khẩu: việc đó thuộc về trình quản lý mật khẩu.
  #   doc     — tài liệu tải lên
  enum :kind, { link: 0, account: 1, doc: 2 }, prefix: true

  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true

  has_one_attached :file

  validates :label, presence: true
  validate  :url_looks_like_url
  validate  :doc_needs_file

  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_position, on: :create
  before_validation :normalize_url

  def display_host
    return nil if url.blank?
    URI.parse(url).host&.sub(/\Awww\./, "")
  rescue URI::InvalidURIError
    nil
  end

  private

  def assign_position
    self.position ||= (project&.project_resources&.where(kind: kind)&.maximum(:position) || -1) + 1
  end

  # Người dùng gõ "xstudio.vn" thì tự thêm https://. Nhưng nếu họ đã gõ một
  # scheme khác (ftp://, javascript:…) thì KHÔNG ghép thêm — ghép vào sẽ tạo
  # ra "https://ftp://abc" và lọt qua kiểm tra.
  def normalize_url
    return if url.blank?
    self.url = url.to_s.strip
    return if url.match?(%r{\Ahttps?://}i)
    return if url.match?(/\A[a-z][a-z0-9+.\-]*:/i) # đã có scheme nào đó
    self.url = "https://#{url}"
  end

  def url_looks_like_url
    return if url.blank?

    unless url.match?(%r{\Ahttps?://}i)
      return errors.add(:url, "chỉ nhận đường dẫn http:// hoặc https://")
    end

    host = URI.parse(url).host
    errors.add(:url, "thiếu tên miền hợp lệ") if host.blank? || !host.include?(".")
  rescue URI::InvalidURIError
    errors.add(:url, "không đọc được, kiểm tra lại")
  end

  def doc_needs_file
    return unless kind_doc?
    errors.add(:file, :blank) unless file.attached?
  end
end
