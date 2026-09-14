import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.element.remove(), 6000)
  }
  disconnect() { clearTimeout(this.timer) }
  dismiss(event) { event.target.closest(".x-toast").remove() }
}
