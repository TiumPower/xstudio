import { Controller } from "@hotwired/stimulus"

// Popup mở trong turbo-frame "modal". Đóng = xoá rỗng frame đó.
export default class extends Controller {
  connect() {
    this.onKey = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    this.previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
    this.element.querySelector("input:not([type=hidden]), select, textarea")?.focus()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    document.body.style.overflow = this.previousOverflow || ""
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.innerHTML = ""
    else this.element.remove()
  }

  backdrop(event) { if (event.target === event.currentTarget) this.close() }
}
