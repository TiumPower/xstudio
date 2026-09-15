import { Controller } from "@hotwired/stimulus"

// Đổi loại hình dự án thì form phải nói đúng ngôn ngữ của loại đó ngay:
// dự án Product là sản phẩm của chính đội nên không có "khách hàng" mà có
// "đối tượng khách hàng", và nó có thêm tab Sản phẩm — điều mà nhìn form
// trống thì không đoán ra được.
export default class extends Controller {
  static targets = ["select", "clientLabel", "clientInput", "productNote"]
  static values  = {
    productLabel: String, clientLabel: String,
    productPlaceholder: String, clientPlaceholder: String
  }

  connect() { this.sync() }

  sync() {
    const isProduct = this.selectTarget.value === "product_sales"

    if (this.hasClientLabelTarget) {
      this.clientLabelTarget.textContent =
        isProduct ? this.productLabelValue : this.clientLabelValue
    }
    if (this.hasClientInputTarget) {
      this.clientInputTarget.placeholder =
        isProduct ? this.productPlaceholderValue : this.clientPlaceholderValue
    }
    if (this.hasProductNoteTarget) {
      this.productNoteTarget.hidden = !isProduct
    }
  }
}
