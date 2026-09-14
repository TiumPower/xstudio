import { Controller } from "@hotwired/stimulus"

// FR-TASK-09 — chọn nhiều và sửa hàng loạt.
export default class extends Controller {
  static targets = ["box", "bar", "count"]

  toggle() { this.refresh() }

  toggleAll(event) {
    this.boxTargets.forEach((box) => { box.checked = event.target.checked })
    this.refresh()
  }

  refresh() {
    const selected = this.boxTargets.filter((b) => b.checked).length
    this.countTarget.textContent = selected
    this.barTarget.classList.toggle("hidden", selected === 0)
  }
}
