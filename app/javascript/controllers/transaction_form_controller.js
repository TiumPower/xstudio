import { Controller } from "@hotwired/stimulus"

// Đổi Thu ↔ Chi thì đổi luôn danh sách danh mục tương ứng.
// Ô đang ẩn phải được `disabled` để trình duyệt không gửi category_id của
// loại kia lên server.
export default class extends Controller {
  static targets = ["group"]

  connect() { this.sync() }

  sync() {
    const kind = this.element.querySelector('input[name="transaction[kind]"]:checked')?.value
    this.groupTargets.forEach((group) => {
      const active = group.dataset.kind === kind
      group.hidden = !active
      group.querySelectorAll("select, input").forEach((field) => { field.disabled = !active })
    })
  }
}
