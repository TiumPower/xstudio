# Triển khai Xstudio — xstudio.czin.net

Chạy trên cùng server VOX với Loyalty, Estate và Bơi Đạt (`103.116.38.152`).

## 1. Chuẩn bị một lần trên server

```bash
# CSDL
sudo -u postgres createuser xstudio --createdb
sudo -u postgres psql -c "ALTER USER xstudio WITH PASSWORD '<mật khẩu>';"
sudo -u postgres createdb xstudio_production -O xstudio

# Thư mục
sudo mkdir -p /var/www/xstudio/shared
sudo chown -R deploy:deploy /var/www/xstudio
```

`/var/www/xstudio/shared/.env` (theo `.env.example`):

```
APP_HOST=xstudio.czin.net
RAILS_ENV=production
DATABASE_NAME=xstudio_production
DATABASE_USER=xstudio
DATABASE_PASSWORD=<mật khẩu>
REDIS_URL=redis://localhost:6379/5
SECRET_KEY_BASE=<bin/rails secret>
ANTHROPIC_API_KEY=<khoá Claude>
MAIL_FROM=Team Workspace <no-reply@xstudio.czin.net>
```

> **Lưu ý Redis:** mỗi app dùng một số database riêng để hàng đợi không lẫn nhau
> (loyalty `/2`, estate `/3`, boidat `/4`, xstudio `/5`).

## 2. Deploy

```bash
cap production deploy
```

Server clone thẳng từ `git@github.com:vietlee/xstudio.git` bằng **SSH agent
forwarding** (`forward_agent: true` trong `config/deploy/production.rb`), nên máy
chạy lệnh deploy phải có khoá GitHub nạp sẵn trong ssh-agent:

```bash
ssh-add -l   # phải thấy khoá; nếu trống thì ssh-add ~/.ssh/id_ed25519
```

## 3. nginx + TLS (làm tay, một lần)

```bash
sudo cp config/nginx/xstudio.czin.net.conf /etc/nginx/sites-available/xstudio.czin.net
sudo ln -sf /etc/nginx/sites-available/xstudio.czin.net /etc/nginx/sites-enabled/
sudo certbot --nginx -d xstudio.czin.net
sudo nginx -t && sudo systemctl reload nginx
```

> **Bắt buộc cho realtime cây định hướng:** vhost phải có khối `location ^~ /cable`
> với `Upgrade`/`Connection` (đã có sẵn trong `config/nginx/xstudio.czin.net.conf`).
> Thiếu nó thì WebSocket không nâng cấp được và thay đổi của người này không
> hiện sang người khác — trang vẫn chạy bình thường nên rất dễ bỏ sót.

## 4. Sidekiq (systemd, một lần)

`/etc/systemd/system/sidekiq-xstudio.service` — xem `config/systemd/sidekiq-xstudio.service`.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sidekiq-xstudio
```

## 5. Khởi tạo dữ liệu

```bash
cap production deploy:seed      # danh mục thu chi + dữ liệu demo (chỉ khi CSDL trống)
```

Sau đó đổi email/mật khẩu tài khoản quản trị và mời thành viên thật qua
**Thành viên → Mời thành viên**.

Lệnh này **an toàn khi chạy lại**: nếu CSDL đã có người dùng, nó chỉ cập nhật
cấu hình workspace và danh mục thu chi, không đụng tới tài khoản nào.

## Việc chạy theo lịch

`sidekiq-cron` đọc `config/sidekiq.yml`:

| Giờ (VN) | Job | Việc |
|---|---|---|
| 07:30 | `DueReminderJob` | nhắc hạn trước 1 ngày + quét quá hạn |
| 08:00 | `DailyDigestJob` | bản tin tổng hợp hàng ngày |
| 23:00 | `TreeSnapshotJob` | ảnh chụp cây định hướng nếu có thay đổi |
| 03:15 | cron hệ thống | sao lưu CSDL, giữ 30 ngày |

## Những chỗ dễ vấp

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Deploy xong nhưng `systemctl --user start` báo *bad unit file setting* | `cap production puma:install` sinh unit đặt biến môi trường ngay trong `ExecStart` — systemd từ chối | Chép `config/systemd/xstudio_puma_production.service` đè lên `~/.config/systemd/user/`, rồi `systemctl --user daemon-reload` |
| Thay đổi cây không hiện sang người khác | nginx thiếu `location /cable`, hoặc gem `redis` lên 6.x (actioncable 7.2 yêu cầu `< 6`) | Kiểm tra vhost; giữ `gem "redis", "~> 5.4"` trong Gemfile |
| Email không tới | Chưa có `SMTP_*` trong `shared/.env` — production đang `delivery_method = :logger` | Điền SMTP rồi `systemctl --user reload xstudio_puma_production` |
| Nút ✨ hiện “AI chưa cấu hình” | Thiếu `ANTHROPIC_API_KEY` | Điền vào `shared/.env`, reload puma |
