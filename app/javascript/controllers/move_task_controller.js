import { Controller } from "@hotwired/stimulus"

// FR-TASK-16 — chuyển công việc sang dự án khác, mở từ thẻ Kanban hoặc từ
// danh sách công việc.
//
// Một hộp dùng chung cho cả trang chứ không phải mỗi hàng/thẻ một menu: menu
// nằm trong vùng có thanh cuộn sẽ bị cắt mất, mà nhân bản danh sách dự án cho
// vài chục dòng cũng chỉ phình DOM. Mỗi lần mở chỉ trỏ `action` của form sang
// công việc vừa bấm.
export default class extends Controller {
  static targets = ["dialog", "form", "select", "summary"]
  static values  = { url: String }

  open(event) {
    event.stopPropagation()
    if (!this.hasDialogTarget) return
    const { taskCode, taskTitle } = event.currentTarget.dataset
    this.formTarget.action = this.urlValue.replace("__CODE__", encodeURIComponent(taskCode))
    this.summaryTarget.textContent = taskTitle ? `${taskCode} · ${taskTitle}` : taskCode
    this.dialogTarget.classList.remove("hidden")
    this.dialogTarget.classList.add("flex")
    this.onKey = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    this.selectTarget?.focus()
  }

  close() {
    if (!this.hasDialogTarget) return
    this.dialogTarget.classList.add("hidden")
    this.dialogTarget.classList.remove("flex")
    document.removeEventListener("keydown", this.onKey)
  }

  disconnect() {
    if (this.onKey) document.removeEventListener("keydown", this.onKey)
  }

  backdrop(event) { if (event.target === event.currentTarget) this.close() }

  // Máy chủ trả về turbo_stream để cập nhật tại chỗ, nên hộp phải tự đóng;
  // gửi hỏng thì giữ nguyên để người dùng sửa rồi gửi lại.
  submitted(event) {
    if (event.detail?.success) this.close()
  }
}
