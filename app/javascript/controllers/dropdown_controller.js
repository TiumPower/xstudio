import { Controller } from "@hotwired/stimulus"

// Menu thả xuống — đóng khi bấm ra ngoài hoặc nhấn Esc.
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.onOutside = (e) => { if (!this.element.contains(e.target)) this.close() }
    this.onKey = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("click", this.onOutside)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("click", this.onOutside)
    document.removeEventListener("keydown", this.onKey)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden = !this.menuTarget.hidden
  }

  close() { if (this.hasMenuTarget) this.menuTarget.hidden = true }
}
