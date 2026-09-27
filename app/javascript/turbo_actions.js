// Turbo bỏ qua <turbo-stream action="refresh"> khi chính trang đó vừa gửi request
// (nó coi là "recent request" và tránh nạp lại hai lần). Form trong popup rơi
// đúng vào trường hợp này: popup đóng nhưng dữ liệu phía sau không đổi.
// Hành động dưới đây điều hướng thật nên luôn chạy.
//
// Dùng window.Turbo (do @hotwired/turbo-rails đặt ở dòng import đầu tiên của
// application.js) thay vì import "@hotwired/turbo" — importmap chỉ ghim turbo-rails.
window.Turbo.StreamActions.redirect = function () {
  const url = this.getAttribute("url") || this.target
  if (url) window.Turbo.visit(url, { action: "replace" })
}

// Đổi đường dẫn trên thanh địa chỉ mà không nạp lại trang. Dùng khi dữ liệu
// trên trang vừa được thay tại chỗ nhưng URL cũ không còn đúng nữa — ví dụ
// công việc chuyển sang dự án khác thì mã việc (cũng là URL) đổi theo.
window.Turbo.StreamActions.replace_url = function () {
  const url = this.getAttribute("url") || this.target
  if (url) window.history.replaceState(window.history.state, "", url)
}

// Đổi tên tab trình duyệt khi nội dung trang vừa được thay tại chỗ.
window.Turbo.StreamActions.set_title = function () {
  const title = this.getAttribute("title") || this.target
  if (title) document.title = title
}
