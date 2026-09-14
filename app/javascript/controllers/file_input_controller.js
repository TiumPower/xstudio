import { Controller } from "@hotwired/stimulus"

// Ô chọn tệp gốc của trình duyệt hiện chuỗi tiếng Anh ("Choose File / No file
// chosen") mà CSS không đổi được. Giấu nó đi, hiển thị nhãn tiếng Việt và tên
// tệp đã chọn.
export default class extends Controller {
  static targets = ["input", "label"]

  connect() { this.render() }

  render() {
    const files = this.inputTarget.files
    if (!files || files.length === 0) {
      this.labelTarget.textContent = this.inputTarget.dataset.emptyText || "Chưa chọn tệp nào"
      this.labelTarget.style.color = "var(--ink-3)"
    } else if (files.length === 1) {
      this.labelTarget.textContent = files[0].name
      this.labelTarget.style.color = "var(--ink)"
    } else {
      this.labelTarget.textContent = `${files.length} tệp đã chọn`
      this.labelTarget.style.color = "var(--ink)"
    }
  }

  open() { this.inputTarget.click() }
}
