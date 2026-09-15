// Thay hộp xác nhận mặc định của trình duyệt (kèm dòng "xstudio.czin.net says")
// bằng hộp thoại HTML của chính app.
//
// Turbo cho phép thay hàm xác nhận: trả về Promise<boolean>.
// Dùng thẻ <dialog> gốc nên có sẵn bẫy tiêu điểm, phím Esc và lớp phủ.

function buildDialog() {
  const dialog = document.createElement("dialog")
  dialog.id = "x-confirm"
  dialog.className = "x-confirm"
  dialog.innerHTML = `
    <form method="dialog" class="x-confirm-body">
      <h2 class="x-h3 mb-1.5" data-slot="title">Xác nhận</h2>
      <p class="x-sub mb-5" data-slot="message"></p>
      <div class="flex items-center justify-end gap-2">
        <button value="cancel" class="x-btn x-btn-ghost">Huỷ</button>
        <button value="confirm" class="x-btn x-btn-primary" data-slot="ok">Xác nhận</button>
      </div>
    </form>`
  document.body.appendChild(dialog)
  return dialog
}

function dialogElement() {
  return document.getElementById("x-confirm") || buildDialog()
}

// Thao tác xoá thì nút xác nhận màu đỏ và đổi chữ cho đúng việc.
function isDestructive(element, submitter) {
  const method = (submitter || element)?.dataset?.turboMethod ||
                 element?.querySelector?.('input[name="_method"]')?.value ||
                 element?.getAttribute?.("method")
  return String(method).toLowerCase() === "delete"
}

// Gọi trực tiếp được từ JS của app, không chỉ từ Turbo.
window.xConfirm = function (message, { destructive = false } = {}) {
  const dialog = dialogElement()

  dialog.querySelector('[data-slot="message"]').textContent = message
  dialog.querySelector('[data-slot="title"]').textContent = destructive ? "Xác nhận xoá" : "Xác nhận"

  const ok = dialog.querySelector('[data-slot="ok"]')
  ok.textContent = destructive ? "Xoá" : "Đồng ý"
  ok.className = destructive ? "x-btn x-btn-danger" : "x-btn x-btn-primary"

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
    dialog.showModal()
    ok.focus()
  })
}

window.Turbo.setConfirmMethod((message, element, submitter) =>
  window.xConfirm(message, { destructive: isDestructive(element, submitter) })
)


// ---------------------------------------------------------------------------
// Hộp NHẬP LIỆU dạng HTML, thay window.prompt() (vốn hiện cả tên miền và
// không theo giao diện app). Trả về Promise<string|null>.
// ---------------------------------------------------------------------------
function buildPrompt() {
  const dialog = document.createElement("dialog")
  dialog.id = "x-prompt"
  dialog.className = "x-confirm"
  dialog.innerHTML = `
    <form method="dialog" class="x-confirm-body">
      <h2 class="x-h3 mb-1.5" data-slot="title">Nhập</h2>
      <p class="x-sub mb-3" data-slot="message" hidden></p>
      <input type="text" class="x-input mb-5" data-slot="input" autocomplete="off">
      <div class="flex items-center justify-end gap-2">
        <button value="cancel" class="x-btn x-btn-ghost">Huỷ</button>
        <button value="confirm" class="x-btn x-btn-primary" data-slot="ok">Xong</button>
      </div>
    </form>`
  document.body.appendChild(dialog)
  return dialog
}

window.xPrompt = function (title, defaultValue = "", options = {}) {
  const dialog = document.getElementById("x-prompt") || buildPrompt()
  const input = dialog.querySelector('[data-slot="input"]')
  const message = dialog.querySelector('[data-slot="message"]')

  dialog.querySelector('[data-slot="title"]').textContent = title
  message.textContent = options.hint || ""
  message.hidden = !options.hint
  dialog.querySelector('[data-slot="ok"]').textContent = options.okLabel || "Xong"
  input.value = defaultValue
  input.placeholder = options.placeholder || ""
  input.maxLength = options.maxLength || 200

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => {
      resolve(dialog.returnValue === "confirm" ? input.value.trim() : null)
    }, { once: true })
    dialog.showModal()
    input.focus()
    input.select()
  })
}
