import { Controller } from "@hotwired/stimulus"

// Soạn tài liệu Markdown/HTML với bản xem trước cạnh bên.
//
// Xem trước do MÁY CHỦ dựng, đi qua đúng bộ lọc của trang đọc. Dựng ở trình
// duyệt sẽ nhanh hơn nhưng lại cho thấy một kết quả khác với cái được lưu —
// người viết sẽ không biết thẻ nào vừa bị lọc bỏ.
export default class extends Controller {
  static targets = ["input", "format", "preview", "pane", "toggle"]
  static values  = { url: String }

  connect() {
    this.timer = null
    this.last  = null
    this.render()
  }

  disconnect() { clearTimeout(this.timer) }

  // Gõ tới đâu xem tới đó, nhưng chờ ngưng gõ mới gọi máy chủ.
  changed() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.render(), 400)
  }

  // Đổi Markdown ↔ HTML thì dựng lại ngay, không cần chờ.
  reformat() {
    clearTimeout(this.timer)
    this.render()
  }

  async render() {
    if (!this.hasPreviewTarget || this.paneTarget.hidden) return

    const content = this.inputTarget.value
    const format  = this.formatValue()
    const key     = format + " :: " + content
    if (key === this.last) return
    this.last = key

    if (!content.trim()) {
      this.previewTarget.innerHTML =
        '<p class="x-muted">Chưa có nội dung — gõ vào ô bên trái để xem trước.</p>'
      return
    }

    const body = new FormData()
    body.append("content", content)
    body.append("content_format", format)

    try {
      const res = await fetch(this.urlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content },
        body
      })
      if (!res.ok) throw new Error(res.status)
      this.previewTarget.innerHTML = await res.text()
    } catch (_e) {
      this.previewTarget.innerHTML =
        '<p class="x-muted">Chưa dựng được bản xem trước. Nội dung bạn gõ vẫn còn nguyên.</p>'
    }
  }

  formatValue() {
    const checked = this.formatTargets.find((el) => el.checked)
    return checked ? checked.value : "markdown"
  }

  // Màn hình hẹp không đủ chỗ cho hai cột — bật/tắt cột xem trước.
  toggle() {
    this.paneTarget.hidden = !this.paneTarget.hidden
    this.toggleTarget.textContent = this.paneTarget.hidden ? "Xem trước" : "Ẩn xem trước"
    if (!this.paneTarget.hidden) { this.last = null; this.render() }
  }

  // Tab trong ô soạn thảo phải là thụt lề, không phải nhảy sang nút khác.
  tab(event) {
    if (event.key !== "Tab" || event.shiftKey) return
    event.preventDefault()
    const el = this.inputTarget
    const { selectionStart: s, selectionEnd: e } = el
    el.value = el.value.slice(0, s) + "  " + el.value.slice(e)
    el.selectionStart = el.selectionEnd = s + 2
    this.changed()
  }
}
