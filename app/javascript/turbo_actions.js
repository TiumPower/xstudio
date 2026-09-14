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
