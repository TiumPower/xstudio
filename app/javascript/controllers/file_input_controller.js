import { Controller } from "@hotwired/stimulus"

// Ô chọn tệp gốc của trình duyệt hiện chuỗi tiếng Anh ("Choose File / No file
// chosen") mà CSS không đổi được. Giấu nó đi, tự vẽ nút tiếng Việt và danh sách
// tệp đã chọn dạng chip — mỗi chip bỏ được riêng, không phải chọn lại từ đầu.
export default class extends Controller {
  static targets = ["input", "label"]

  connect() { this.render() }

  render() {
    const files = Array.from(this.inputTarget.files || [])
    this.labelTarget.replaceChildren(
      ...(files.length === 0 ? [this.emptyNode()] : files.map((file, i) => this.chip(file, i)))
    )
  }

  emptyNode() {
    const span = document.createElement("span")
    span.className = "x-filepick-empty"
    span.textContent = this.inputTarget.dataset.emptyText || "Chưa chọn tệp nào"
    return span
  }

  chip(file, index) {
    const chip = document.createElement("span")
    chip.className = "x-chip x-filepick-chip"

    const name = document.createElement("span")
    name.className = "x-filepick-name"
    name.textContent = file.name
    name.title = file.name

    const size = document.createElement("span")
    size.className = "x-filepick-size"
    size.textContent = this.humanSize(file.size)

    const remove = document.createElement("button")
    remove.type = "button"
    remove.textContent = "×"
    remove.setAttribute("aria-label", `Bỏ ${file.name}`)
    remove.addEventListener("click", (event) => {
      event.preventDefault()
      this.drop(index)
    })

    chip.append(name, size, remove)
    return chip
  }

  // Bỏ một tệp khỏi danh sách: FileList chỉ ghi được bằng DataTransfer.
  drop(index) {
    const kept = new DataTransfer()
    Array.from(this.inputTarget.files).forEach((file, i) => { if (i !== index) kept.items.add(file) })
    this.inputTarget.files = kept.files
    this.render()
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    const kb = bytes / 1024
    return kb < 1024 ? `${this.round(kb)} KB` : `${this.round(kb / 1024)} MB`
  }

  round(value) { return (Math.round(value * 10) / 10).toString().replace(".", ",") }

  open() { this.inputTarget.click() }
}
