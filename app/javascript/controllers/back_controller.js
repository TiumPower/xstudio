import { Controller } from "@hotwired/stimulus"

// Nút Quay lại. Ưu tiên lịch sử trình duyệt; nếu người dùng mở thẳng URL
// (không có lịch sử trong tab) thì đi tới đường dẫn cha ghi trong href.
export default class extends Controller {
  go(event) {
    event.preventDefault()
    const sameTabHistory = window.history.length > 1 && document.referrer.startsWith(window.location.origin)
    if (sameTabHistory) window.history.back()
    else window.Turbo.visit(this.element.getAttribute("href"))
  }
}
