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

## 3. nginx + TLS (làm tay, một lần)

```bash
sudo cp config/nginx/xstudio.czin.net.conf /etc/nginx/sites-available/xstudio.czin.net
sudo ln -sf /etc/nginx/sites-available/xstudio.czin.net /etc/nginx/sites-enabled/
sudo certbot --nginx -d xstudio.czin.net
sudo nginx -t && sudo systemctl reload nginx
```

## 4. Sidekiq (systemd, một lần)

`/etc/systemd/system/sidekiq-xstudio.service` — xem `config/systemd/sidekiq-xstudio.service`.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sidekiq-xstudio
```

## 5. Khởi tạo dữ liệu

```bash
cap production deploy:seed      # danh mục thu chi + tài khoản quản trị đầu tiên
```

Sau đó đổi mật khẩu tài khoản quản trị và mời thành viên thật qua
**Thành viên → Mời thành viên**.

## Việc chạy theo lịch

`sidekiq-cron` đọc `config/sidekiq.yml`:

| Giờ (VN) | Job | Việc |
|---|---|---|
| 07:30 | `DueReminderJob` | nhắc hạn trước 1 ngày + quét quá hạn |
| 08:00 | `DailyDigestJob` | bản tin tổng hợp hàng ngày |
| 23:00 | `TreeSnapshotJob` | ảnh chụp cây định hướng nếu có thay đổi |
| 03:15 | cron hệ thống | sao lưu CSDL, giữ 30 ngày |
