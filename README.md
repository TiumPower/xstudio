# Xstudio — Team Workspace

Công cụ làm việc nội bộ của đội: dự án, công việc + Kanban, thu chi, tổng quan,
thông báo, và cây định hướng có AI gợi ý nhánh.

Toàn bộ giao diện, email và thông báo lỗi **bằng tiếng Việt**. Tiền tệ **VND**
(`15.000.000 ₫`), ngày `dd/mm/yyyy`, múi giờ `Asia/Ho_Chi_Minh`.

- Sản phẩm: <https://xstudio.czin.net>
- Tài liệu yêu cầu: `docs/SRS-Team-Workspace.md`

## Stack

| Thành phần | Lựa chọn |
|---|---|
| Framework | Rails 7.2 (full-stack) |
| CSDL | PostgreSQL |
| Giao diện động | Hotwire (Turbo + Stimulus) |
| CSS | TailwindCSS v4 + design tokens `app/assets/tailwind/application.css` |
| Kéo–thả Kanban | SortableJS trong `kanban_controller.js` |
| Canvas cây định hướng | SVG tự vẽ + tự bố trí tidy-tree trong `tree_controller.js` |
| Xác thực | Devise (lời mời tự triển khai trên bảng `users`) |
| Hàng đợi nền | Sidekiq + sidekiq-cron |
| AI | Claude API (`ClaudeService`), chỉ dùng cho gợi ý nhánh cây |
| Xuất Excel | caxlsx |
| Triển khai | Capistrano → puma (daemon) + nginx + systemd sidekiq |

## Chạy ở máy local

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/dev            # web + tailwind watch, cổng 3012
```

Đăng nhập demo: `na@xstudio.vn` / `xstudio2026`

Email ở local mở bằng `letter_opener` (tự bật tab trình duyệt).
Sidekiq: `bundle exec sidekiq` (cần Redis ở `redis://localhost:6379/2`).

## Biến môi trường

Xem `.env.example`. Ở production chúng nằm trong `/var/www/xstudio/shared/.env`.

| Biến | Tác dụng |
|---|---|
| `ANTHROPIC_API_KEY` | Bật nút ✨ gợi ý nhánh cây. Thiếu khoá thì cây vẫn dùng tay được đầy đủ. |
| `SMTP_*` | Bật email thật. Thiếu thì email chỉ ghi log, thông báo trong app vẫn chạy. |
| `SECRET_KEY_BASE` | Bắt buộc ở production. |

## Triển khai

```bash
cap production deploy
```

Lần đầu trên server cần làm tay (xem `docs/DEPLOY.md`): tạo DB + user Postgres,
`shared/.env`, nginx vhost (`config/nginx/xstudio.czin.net.conf`), chứng chỉ
Certbot, và unit `sidekiq-xstudio.service`.

## Bố cục mã nguồn

```
app/models/          Project · Task · Transaction · StrategyTree/Node · …
app/services/
  finance/           bộ lọc sổ thu chi, tổng hợp, xuất CSV
  reporting/         số liệu trang Tổng quan, chuỗi theo tháng
  notifications/     Dispatch — nơi duy nhất tạo thông báo + xếp email
  strategy/          parser dán hàng loạt, dựng nhánh, ảnh chụp, gợi ý AI
app/javascript/controllers/
  kanban_controller.js   kéo–thả bảng Kanban
  tree_controller.js     canvas cây định hướng (SVG, phím tắt, AI, undo)
config/locales/vi.yml    toàn bộ chuỗi tiếng Việt
```
