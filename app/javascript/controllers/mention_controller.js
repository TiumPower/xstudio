import { Controller } from "@hotwired/stimulus"

// FR-CMT-03 — gõ "@" để nhắc tên. Chèn vào ô nhập dưới dạng @[Tên](id).
export default class extends Controller {
  static targets = ["input", "menu", "people"]

  connect() {
    this.people = JSON.parse(this.peopleTarget.textContent || "[]")
    this.index = 0
    this.matches = []
  }

  scan() {
    const value = this.inputTarget.value
    const caret = this.inputTarget.selectionStart
    const match = value.slice(0, caret).match(/@([\p{L}\p{N}\s]{0,20})$/u)

    if (!match) return this.hide()

    this.query = match[1].trim().toLowerCase()
    this.start = caret - match[0].length
    this.matches = this.people
      .filter((p) => !this.query || p.name.toLowerCase().includes(this.query))
      .slice(0, 6)

    if (this.matches.length === 0) return this.hide()
    this.index = 0
    this.render()
  }

  render() {
    this.menuTarget.innerHTML = this.matches
      .map((p, i) => `<button type="button" data-index="${i}"
        class="block w-full text-left px-3 py-2 rounded-lg text-[13px] ${i === this.index ? "bg-[var(--brand-soft)]" : ""}">${p.name}</button>`)
      .join("")
    this.menuTarget.hidden = false
    this.menuTarget.querySelectorAll("button").forEach((button) =>
      button.addEventListener("mousedown", (event) => {
        event.preventDefault()
        this.pick(Number(button.dataset.index))
      })
    )
  }

  navigate(event) {
    if (this.menuTarget.hidden) return
    if (event.key === "ArrowDown") { event.preventDefault(); this.index = (this.index + 1) % this.matches.length; this.render() }
    else if (event.key === "ArrowUp") { event.preventDefault(); this.index = (this.index - 1 + this.matches.length) % this.matches.length; this.render() }
    else if (event.key === "Enter" || event.key === "Tab") { event.preventDefault(); this.pick(this.index) }
    else if (event.key === "Escape") { this.hide() }
  }

  pick(index) {
    const person = this.matches[index]
    if (!person) return
    const input = this.inputTarget
    const caret = input.selectionStart
    const token = `@[${person.name}](${person.id}) `
    input.value = input.value.slice(0, this.start) + token + input.value.slice(caret)
    input.setSelectionRange(this.start + token.length, this.start + token.length)
    input.focus()
    this.hide()
  }

  hide() { this.menuTarget.hidden = true }
}
