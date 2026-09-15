# Dựng HTML hiển thị từ tài liệu người dùng viết (Markdown hoặc HTML).
#
# Quan trọng: HTML ở đây do thành viên trong đội gõ vào và sẽ hiện trên trình
# duyệt của người khác. Không lọc thì một thẻ <script> hay một href
# "javascript:…" sẽ chạy dưới phiên đăng nhập của đồng đội. Nên MỌI đường ra
# đều đi qua `sanitize` với danh sách thẻ cho phép — kể cả Markdown, vì
# Markdown cho nhúng HTML thô.
#
# Bản gốc người dùng gõ được lưu nguyên trong CSDL; HTML dựng lại mỗi lần đọc.
# Nhờ vậy siết bộ lọc lúc nào là mọi tài liệu cũ được áp dụng ngay lúc đó.
module Markup
  TAGS = %w[
    p br hr div span
    h1 h2 h3 h4 h5 h6
    ul ol li dl dt dd
    strong em b i u s del ins mark small sup sub abbr kbd
    code pre blockquote
    a img
    table thead tbody tfoot tr th td caption
    details summary
  ].freeze

  ATTRS = %w[
    href src alt title
    colspan rowspan
    start reversed
    align
    target rel
    open
  ].freeze

  # Chỉ cho phép giao thức an toàn — chặn javascript:, data:, vbscript:
  PROTOCOLS = %w[http https mailto].freeze

  MAX_LENGTH = 400_000 # ~400KB, đủ cho tài liệu dài mà không làm nghẽn trang

  module_function

  def render(text, format)
    return "".html_safe if text.blank?

    raw = format.to_s == "html" ? text.to_s : markdown_to_html(text.to_s)
    clean = sanitizer.sanitize(drop_code_bearing_nodes(raw), tags: TAGS, attributes: ATTRS, protocols: PROTOCOLS)
    external_links_open_safely(clean)
  end

  # Đoạn văn bản thuần để dùng cho tìm kiếm / trích dẫn ngắn.
  def to_plain(text, format, limit: 160)
    html = render(text, format)
    ActionController::Base.helpers.strip_tags(html).squish.truncate(limit)
  end

  def markdown_to_html(text)
    markdown.render(text)
  end

  def markdown
    @markdown ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(hard_wrap: true),
      tables: true, fenced_code_blocks: true, autolink: true,
      strikethrough: true, superscript: true, footnotes: true,
      no_intra_emphasis: true, lax_spacing: true, space_after_headers: true
    )
  end

  # `sanitize` bỏ THẺ nhưng giữ lại phần chữ bên trong — với <script> thì kết
  # quả là mã lệnh hiện ra giữa tài liệu như văn bản. Vô hại nhưng bẩn, nên
  # bỏ hẳn cả nút lẫn ruột trước khi lọc.
  GUTTED = %w[script style template iframe object embed noscript svg math].freeze

  def drop_code_bearing_nodes(html)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.css(*GUTTED).each(&:remove)
    doc.to_html
  end

  def sanitizer
    @sanitizer ||= Rails::HTML5::SafeListSanitizer.new
  end

  # Liên kết ra ngoài mở tab mới và cắt `window.opener` — trang đích không
  # điều khiển được tab gốc.
  def external_links_open_safely(html)
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.css("a[href]").each do |a|
      next unless a["href"].to_s.match?(%r{\Ahttps?://}i)
      a["target"] = "_blank"
      a["rel"]    = "noopener noreferrer"
    end
    doc.to_html.html_safe
  end
end
