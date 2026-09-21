module ApplicationHelper
  # ---- Tiền tệ (NFR: 15.000.000 ₫, số nguyên, âm màu đỏ) -----------------
  def format_vnd(amount, signed: false)
    return "0 ₫" if amount.blank?
    value = amount.to_i
    sign  = if signed && value.positive? then "+ "
            elsif value.negative?        then "− "
            else "" end
    "#{sign}#{number_with_delimiter(value.abs, delimiter: '.')} ₫"
  end

  def money_tag(amount, signed: false, tone: nil)
    value = amount.to_i
    tone ||= if value.negative? then :bad
             elsif signed && value.positive? then :good
             end
    klass = { good: "x-in", bad: "x-out" }[tone]
    tag.span format_vnd(value, signed: signed), class: ["x-money", klass]
  end

  # ---- Ngày giờ ---------------------------------------------------------
  def format_date(date) = date.present? ? l(date.to_date, format: :default) : "—"

  def format_datetime(time) = time.present? ? l(time.in_time_zone, format: :default) : "—"

  # Hiển thị tương đối cho sự kiện < 7 ngày, ngày tháng cho cũ hơn.
  def time_ago(time)
    return "—" if time.blank?
    time = time.in_time_zone
    return format_date(time) if time < 7.days.ago
    diff = Time.current - time
    return "vừa xong" if diff < 60
    "#{time_ago_in_words(time)} trước"
  end

  def due_label(date)
    return t("common.no_due_date") if date.blank?
    date = date.to_date
    return "Hôm nay"  if date == Date.current
    return "Ngày mai" if date == Date.current + 1
    return "Hôm qua"  if date == Date.current - 1
    l(date, format: :default)
  end

  def overdue_days(date) = date.present? ? (Date.current - date.to_date).to_i : 0

  # ---- Avatar -----------------------------------------------------------
  AVATAR_SIZES = { sm: "x-avatar-sm", md: "", lg: "x-avatar-lg", xl: "x-avatar-xl" }.freeze

  def avatar_for(user, size: :md, title: nil)
    return tag.span("?", class: ["x-avatar", AVATAR_SIZES[size]]) if user.blank?
    klass = ["x-avatar", AVATAR_SIZES[size]].compact_blank
    if user.avatar.attached?
      tag.span(class: klass, title: title || user.display_name) do
        image_tag(user.avatar.variant(resize_to_fill: [128, 128]), alt: user.display_name)
      end
    else
      tag.span(user.initials, class: klass, style: "background:#{user.avatar_color}",
               title: title || user.display_name)
    end
  end

  def avatar_stack(users, limit: 3, size: :sm)
    users = Array(users).compact
    shown = users.first(limit)
    tag.span(class: "x-avatar-stack") do
      safe_join(shown.map { |u| avatar_for(u, size: size) }) +
        (users.size > limit ? tag.span("+#{users.size - limit}", class: ["x-avatar", AVATAR_SIZES[size]], style: "background:var(--ink-3)") : "".html_safe)
    end
  end

  # ---- Chip ---------------------------------------------------------------
  def project_type_chip(project)
    klass = project.product_sales? ? "x-chip-ps" : "x-chip-dx"
    tag.span(project.type_label, class: "x-chip #{klass}")
  end

  PROJECT_STATUS_CHIP = {
    "planning"    => "x-chip",
    "in_progress" => "x-chip-brand",
    "on_hold"     => "x-chip-warn",
    "completed"   => "x-chip-good",
    "cancelled"   => "x-chip-bad"
  }.freeze

  def project_status_chip(project)
    tag.span t("project_statuses.#{project.status}"),
             class: "x-chip #{PROJECT_STATUS_CHIP[project.status]}"
  end

  PRIORITY_CHIP = { "low" => "x-chip", "medium" => "x-chip-brand", "high" => "x-chip-warn", "urgent" => "x-chip-bad" }.freeze

  def priority_chip(task)
    tag.span task.priority_label, class: "x-chip #{PRIORITY_CHIP[task.priority]}"
  end

  def node_status_chip(node)
    tag.span node.status_label, class: "x-chip",
             style: "background:#{node.status_color}1A;color:#{node.status_color}"
  end

  # ---- Điều hướng -------------------------------------------------------
  def nav_link(label, path, icon:, match: :prefix, badge: nil)
    active = match == :exact ? current_page?(path) : request.path.start_with?(path.to_s.split("?").first)
    active = current_page?(path) if path.to_s == "/"
    link_to path, class: ["x-nav-item", ("is-active" if active)] do
      safe_join([
        nav_icon(icon),
        tag.span(label, class: "flex-1"),
        (badge.to_i.positive? ? tag.span(badge, class: "text-[10.5px] font-bold px-1.5 py-0.5 rounded-full text-white", style: "background:var(--bad)") : nil)
      ].compact)
    end
  end

  NAV_ICONS = {
    dashboard: '<rect x="2" y="2" width="5.5" height="5.5" rx="1.4"/><rect x="10.5" y="2" width="5.5" height="5.5" rx="1.4"/><rect x="2" y="10.5" width="5.5" height="5.5" rx="1.4"/><rect x="10.5" y="10.5" width="5.5" height="5.5" rx="1.4"/>',
    projects:  '<rect x="2" y="3.5" width="14" height="11" rx="2"/><path d="M2 7h14"/>',
    check:     '<path d="M3 9.5l3.5 3.5L15 4.5"/>',
    money:     '<path d="M9 2v14M5.5 5.5h5.2a2.3 2.3 0 010 4.6H5.5M5.5 10.1h7"/>',
    members:   '<circle cx="7" cy="6" r="2.6"/><path d="M2.5 15c0-2.5 2-4.2 4.5-4.2s4.5 1.7 4.5 4.2"/><circle cx="13" cy="6.5" r="2"/><path d="M12.5 10.9c1.9.1 3.2 1.7 3.2 4.1"/>',
    tree:      '<circle cx="4" cy="9" r="2"/><circle cx="14" cy="4.5" r="2"/><circle cx="14" cy="13.5" r="2"/><path d="M6 8.2l6-2.9M6 9.8l6 2.9"/>',
    activity:  '<path d="M2 9h3l2-5 4 10 2-5h3"/>',
    settings:  '<circle cx="9" cy="9" r="2.6"/><path d="M9 1.5v2M9 14.5v2M16.5 9h-2M3.5 9h-2M14.3 3.7l-1.4 1.4M5.1 12.9l-1.4 1.4M14.3 14.3l-1.4-1.4M5.1 5.1L3.7 3.7"/>'
  }.freeze

  def nav_icon(name)
    tag.svg(NAV_ICONS[name].to_s.html_safe, width: 17, height: 17, viewBox: "0 0 18 18",
            fill: "none", stroke: "currentColor", "stroke-width": 1.5,
            "stroke-linecap": "round", "stroke-linejoin": "round")
  end

  # ---- Tiện ích ---------------------------------------------------------
  def page_title(text)
    content_for(:page_title) { text }
    content_for(:title) { "#{text} · #{current_workspace.name}" }
  end

  def percent(value) = "#{value.to_i}%"

  # `on_dark`: trên nền navy phải dùng sắc sáng, xanh/đỏ gốc sẽ chìm.
  def delta_badge(current, previous, on_dark: false)
    return tag.span("—", class: "x-muted") if previous.to_i.zero?

    pct = ((current.to_f - previous) / previous.abs * 100).round(1)
    up  = pct >= 0
    color = if on_dark then (up ? "#8FE3B4" : "#FFA8A0")
            else (up ? "var(--good)" : "var(--bad)")
            end

    tag.span(class: "text-[12px] font-semibold", style: "color:#{color}") do
      "#{up ? '▲' : '▼'} #{pct.abs.to_s.sub('.', ',')}%"
    end
  end

  def blank_dash(value) = value.presence || tag.span("—", class: "x-muted")

  # Ô ẩn mang theo nơi cần quay về sau khi lưu.
  # Ngoài popup, trang đang đứng chính là nơi cần quay về. Trong popup thì
  # request.fullpath là URL của chính popup (ví dụ /giao-dich/moi) chứ không
  # phải trang người dùng đang xem — lúc đó chỉ nhận return_to do link mở popup
  # truyền vào, không có thì để controller tự quyết.
  def return_to_field
    back = params[:return_to].presence || (request.fullpath unless turbo_frame_request?)
    hidden_field_tag(:return_to, back) if back.present?
  end
end
