class ProjectResource < ApplicationRecord
  # Ba loại tài nguyên của một sản phẩm:
  #   link    — trang web, kho mã, bảng thiết kế…
  #   account — ghi lại DÙNG TÀI KHOẢN NÀO để truy cập (email/tên đăng nhập).
  #             Không lưu mật khẩu: việc đó thuộc về trình quản lý mật khẩu.
  #   doc     — tài liệu: tải tệp lên, HOẶC viết thẳng bằng Markdown/HTML
  enum :kind, { link: 0, account: 1, doc: 2 }, prefix: true

  # Định dạng của tài liệu viết trong app.
  enum :content_format, { markdown: 0, html: 1 }, prefix: :format

  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true

  has_one_attached :file

  validates :label, presence: true
  validates :content, length: { maximum: Markup::MAX_LENGTH,
                                too_long: "dài quá %{count} ký tự — tách thành nhiều tài liệu" }
  validate  :url_looks_like_url
  validate  :doc_needs_body
  validate  :file_within_limit

  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_position, on: :create
  before_validation :normalize_url

  # Trần kích thước tệp. nginx chặn ở 30MB, nhưng chặn ở tầng đó chỉ ra lỗi
  # 413 trống trơn — kiểm ở đây để người dùng thấy câu tiếng Việt tử tế.
  MAX_FILE_SIZE = 25.megabytes

  # Tài liệu viết trong app (khác với tài liệu là tệp tải lên).
  def written? = kind_doc? && content.present?

  # Tệp .md/.html tải lên cũng đọc được ngay trong app, không cần tải về.
  READABLE_EXT = %w[md markdown mdown mkd txt html htm].freeze

  def readable_file?
    return false unless kind_doc? && file.attached?
    return false if file.byte_size > 512.kilobytes # tệp to thì tải về đọc
    READABLE_EXT.include?(file.filename.extension.to_s.downcase)
  end

  # Xem được ngay trong app hay chỉ tải về?
  def viewable? = written? || readable_file?

  # HTML để hiển thị. Dựng lại mỗi lần đọc, luôn đi qua bộ lọc của Markup.
  def rendered_html
    if written?
      Markup.render(content, content_format)
    elsif readable_file?
      Markup.render(file.download.force_encoding("UTF-8"), file_format)
    else
      "".html_safe
    end
  end

  # Tệp .html đọc như HTML, còn lại coi là Markdown (kể cả .txt — Markdown
  # với văn bản thuần vẫn ra đúng văn bản thuần).
  def file_format
    %w[html htm].include?(file.filename.extension.to_s.downcase) ? :html : :markdown
  end

  def excerpt
    return Markup.to_plain(content, content_format) if written?
    note.presence
  end

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

  # Tài liệu phải có NỘI DUNG — hoặc tệp tải lên, hoặc chữ viết trong app.
  # Thiếu cả hai thì chỉ là một cái tên trống, không giúp được ai.
  def file_within_limit
    return unless file.attached?
    return if file.byte_size <= MAX_FILE_SIZE
    errors.add(:file, "nặng quá #{ActiveSupport::NumberHelper.number_to_human_size(MAX_FILE_SIZE)} — nén lại hoặc để trên ổ đám mây rồi dán liên kết")
  end

  def doc_needs_body
    return unless kind_doc?
    return if file.attached? || content.present?
    errors.add(:base, "Tài liệu cần một tệp tải lên hoặc nội dung viết trong app")
  end
end
