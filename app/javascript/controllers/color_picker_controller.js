import { Controller } from "@hotwired/stimulus"

// Bảng màu chọn nhanh + ô chọn tuỳ ý. Bấm một ô là điền luôn giá trị, không
// phải mở bộ chọn màu của hệ điều hành cho từng lần.
export default class extends Controller {
  static targets = ["input", "swatch", "custom"]

  connect() { this.mark() }

  pick(event) {
    this.inputTarget.value = event.currentTarget.dataset.color
    if (this.hasCustomTarget) this.customTarget.value = event.currentTarget.dataset.color
    this.mark()
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  syncCustom() {
    this.inputTarget.value = this.customTarget.value
    this.mark()
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  mark() {
    const current = (this.inputTarget.value || "").toLowerCase()
    this.swatchTargets.forEach((swatch) => {
      swatch.classList.toggle("is-picked", swatch.dataset.color.toLowerCase() === current)
    })
  }
}
