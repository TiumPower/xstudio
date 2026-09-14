import { Controller } from "@hotwired/stimulus"

// Đổi dự án thì nạp lại danh sách cột và thành viên tương ứng.
export default class extends Controller {
  static targets = ["project", "column", "assignee"]

  switchProject() {
    const option = this.projectTarget.selectedOptions[0]
    const form = this.element.querySelector("form")
    form.action = `/du-an/${encodeURIComponent(option.value)}/cong-viec`

    this.fill(this.columnTarget, JSON.parse(option.dataset.columns || "[]"), false)
    this.fill(this.assigneeTarget, JSON.parse(option.dataset.members || "[]"), true)
  }

  fill(select, items, blank) {
    select.innerHTML = ""
    if (blank) select.add(new Option("Chưa giao", ""))
    items.forEach((item) => select.add(new Option(item.name, item.id)))
  }
}
