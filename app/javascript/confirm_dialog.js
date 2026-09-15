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

window.Turbo.setConfirmMethod((message, element, submitter) => {
  const dialog = dialogElement()
  const destructive = isDestructive(element, submitter)

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
})
