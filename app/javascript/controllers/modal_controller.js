import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onKey = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    document.body.style.overflow = "hidden"
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    document.body.style.overflow = ""
  }

  close() { this.element.remove() }

  backdrop(event) { if (event.target === event.currentTarget) this.close() }
}
