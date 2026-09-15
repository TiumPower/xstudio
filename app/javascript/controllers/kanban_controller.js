import { Controller } from "@hotwired/stimulus"

// FR-TASK-05 — kéo–thả giữa cột và sắp xếp trong cột.
// Cập nhật lạc quan: thẻ chuyển ngay, hoàn tác nếu server báo lỗi.
export default class extends Controller {
  static targets = ["list", "composer", "composerInput", "board"]
  static values  = { moveUrl: String, reorderUrl: String }

  connect() {
    this.initColumnSorting()
    this.sortables = this.listTargets.map((list) =>
      new window.Sortable(list, {
        group: "kanban",
        animation: 150,
        ghostClass: "x-drop-hint",
        dragClass: "x-dragging",
        draggable: ".x-tcard",
        onEnd: (event) => this.persist(event)
      })
    )
  }

  disconnect() {
    this.sortables?.forEach((s) => s.destroy())
    this.columnSortable?.destroy()
  }

  // Kéo đầu cột để đổi thứ tự hiển thị các cột (FR-TASK-03).
  initColumnSorting() {
    const board = this.hasBoardTarget ? this.boardTarget : this.element
    this.columnSortable = new window.Sortable(board, {
      group: "kanban-columns",
      draggable: ".x-col",
      handle: ".x-col-grip",
      animation: 150,
      dragClass: "x-col-dragging",
      ghostClass: "x-col-ghost",
      onEnd: () => this.persistColumnOrder(board)
    })
  }

  async persistColumnOrder(board) {
    const ids = [...board.querySelectorAll(".x-col")].map((c) => c.dataset.columnId).filter(Boolean)
    if (ids.length === 0) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("ids[]", id))

    try {
      const response = await fetch(this.reorderUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body
      })
      if (!response.ok) throw new Error("Không lưu được thứ tự cột")
    } catch (error) {
      this.toast(error.message)
    }
  }

  async persist(event) {
    const card = event.item
    const list = event.to
    const code = card.dataset.taskCode
    const columnId = list.dataset.columnId

    const siblings = [...list.querySelectorAll(".x-tcard")]
    const index = siblings.indexOf(card)
    const prev = siblings[index - 1]?.dataset.position || null
    const next = siblings[index + 1]?.dataset.position || null

    try {
      const response = await fetch(this.moveUrlValue.replace("__CODE__", encodeURIComponent(code)), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ board_column_id: columnId, prev_position: prev, next_position: next })
      })
      if (!response.ok) throw new Error((await response.json())?.error?.message || "Không lưu được")
      this.refreshCounts()
    } catch (error) {
      event.from.insertBefore(card, event.from.children[event.oldIndex] || null)
      this.toast(error.message)
    }
  }

  refreshCounts() {
    this.listTargets.forEach((list) => {
      const badge = list.closest(".x-col")?.querySelector(".x-col-head .x-num")
      if (!badge) return
      const limit = badge.textContent.includes("/") ? badge.textContent.split("/")[1] : null
      const count = list.querySelectorAll(".x-tcard").length
      badge.textContent = limit ? `${count} /${limit}` : String(count)
    })
  }

  openComposer(event) {
    const id = event.currentTarget.dataset.columnId
    this.composerTargets.forEach((form) => {
      const match = form.dataset.columnId === id
      form.classList.toggle("hidden", !match)
      form.nextElementSibling?.classList?.toggle("hidden", match)
      if (match) form.querySelector("input[type=text]")?.focus()
    })
  }

  closeComposer(event) {
    const form = event.target.closest("form")
    form.classList.add("hidden")
    form.nextElementSibling?.classList?.remove("hidden")
  }

  // Mở chi tiết trong panel trượt để không mất chỗ đang đứng trên bảng.
  openTask(event) {
    if (event.target.closest("button, a, input")) return
    const code = event.currentTarget.dataset.taskCode
    const frame = document.getElementById("modal")
    if (!frame) return window.Turbo.visit(`/cong-viec/${encodeURIComponent(code)}`)
    frame.src = `/cong-viec/${encodeURIComponent(code)}`
  }

  toast(message) {
    const box = document.createElement("div")
    box.className = "x-toast x-toast-bad fixed bottom-5 right-5 z-[80] max-w-[360px] shadow-lg"
    box.textContent = message
    document.body.appendChild(box)
    setTimeout(() => box.remove(), 5000)
  }
}
