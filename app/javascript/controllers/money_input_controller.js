import { Controller } from "@hotwired/stimulus"

// FR-FIN-08 — gõ 15000000 hiện thành 15.000.000. Gửi lên server vẫn là số thô.
export default class extends Controller {
  connect() { this.format() }

  format() {
    const digits = this.element.value.replace(/\D/g, "")
    this.element.value = digits ? Number(digits).toLocaleString("vi-VN") : ""
  }

  input() {
    const start = this.element.selectionStart
    const before = this.element.value.length
    this.format()
    const diff = this.element.value.length - before
    this.element.setSelectionRange(start + diff, start + diff)
  }
}
