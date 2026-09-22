# Triển khai Xstudio — xstudio.tiumpower.com

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
APP_HOST=xstudio.tiumpower.com
RAILS_ENV=production
DATABASE_NAME=xstudio_production
DATABASE_USER=xstudio
DATABASE_PASSWORD=<mật khẩu>
REDIS_URL=redis://localhost:6379/5
SECRET_KEY_BASE=<bin/rails secret>
ANTHROPIC_API_KEY=<khoá Claude>
MAIL_FROM=Team Workspace <no-reply@xstudio.tiumpower.com>
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
sudo cp config/nginx/xstudio.tiumpower.com.conf /etc/nginx/sites-available/xstudio.tiumpower.com
sudo ln -sf /etc/nginx/sites-available/xstudio.tiumpower.com /etc/nginx/sites-enabled/
sudo certbot --nginx -d xstudio.tiumpower.com
sudo nginx -t && sudo systemctl reload nginx
```

> **Bắt buộc cho realtime cây định hướng:** vhost phải có khối `location ^~ /cable`
> với `Upgrade`/`Connection` (đã có sẵn trong `config/nginx/xstudio.tiumpower.com.conf`).
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

## Lưu trữ tệp đính kèm

App tự chọn nơi lưu theo biến môi trường trong `shared/.env`:

| Có `SPACES_KEY` + `SPACES_BUCKET`? | Nơi lưu |
|---|---|
| Không | Đĩa server — `/var/www/xstudio/shared/storage` (symlink từ `current/storage`) |
| Có | **DigitalOcean Spaces** là kho chính, đĩa giữ bản sao (`config/storage.yml` → `spaces_mirrored`) |
| Có, kèm `SPACES_MIRROR_LOCAL=false` | Chỉ ghi lên Spaces, đĩa không giữ bản sao nào |

Bucket `czin` dùng chung với boidat, estate và loyalty, nên tệp của Xstudio nằm
dưới tiền tố `xstudio/` — tiền tố do `lib/active_storage/service/prefixed_s3_service.rb`
gắn ở tầng service, cột `key` trong CSDL không chứa nó.

Bản sao trên đĩa không thừa: `bin/xstudio_backup.sh` nén `shared/storage` mỗi
chủ nhật, và đó là bản sao thứ hai duy nhất. DO Spaces không có versioning.

Thiếu khoá thì app quay về đĩa chứ không chết, nên đặt thiếu biến không làm
hỏng việc tải tệp lên.

### Bật DigitalOcean Spaces

1. Tạo Space + Spaces access key trên DigitalOcean. **Đặt bucket ở chế độ
   Private** — app tự phát đường dẫn ký tên có hạn khi người dùng tải tệp.
2. Thêm vào `/var/www/xstudio/shared/.env` (chmod 600, không bao giờ vào git):

   ```
   SPACES_KEY=...
   SPACES_SECRET=...
   SPACES_BUCKET=...
   SPACES_REGION=sgp1
   ```

3. Kiểm tra kết nối rồi mới dời tệp:

   ```
   cd /var/www/xstudio/current
   RAILS_ENV=production bundle exec rails storage:check
   DRY=1 RAILS_ENV=production bundle exec rails storage:to_spaces   # xem trước
   RAILS_ENV=production bundle exec rails storage:to_spaces         # chép thật
   ```

   `storage:to_spaces` chạy lại được nhiều lần: chép xong từng tệp mới đổi
   `service_name`, nên dừng giữa chừng thì phần chưa chép vẫn đọc từ đĩa.

4. Khởi động lại app: `systemctl --user restart xstudio_puma_production`
   và `sudo systemctl restart xstudio_sidekiq`.

Giới hạn 25MB/tệp theo NFR; nginx đặt `client_max_body_size 30M`.

Sao lưu (`bin/xstudio_backup.sh`, cron 03:15):
- CSDL: dump mỗi đêm, giữ 30 ngày
- Tệp trên đĩa: nén mỗi **Chủ nhật**, giữ 8 bản (~2 tháng)

> Khi đã chuyển hẳn lên Spaces, bản nén hằng tuần chỉ còn là tàn dư của giai
> đoạn dùng đĩa. Bật versioning/backup phía DigitalOcean cho bucket thay thế.

## Những chỗ dễ vấp

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Deploy xong nhưng `systemctl --user start` báo *bad unit file setting* | `cap production puma:install` sinh unit đặt biến môi trường ngay trong `ExecStart` — systemd từ chối | Chép `config/systemd/xstudio_puma_production.service` đè lên `~/.config/systemd/user/`, rồi `systemctl --user daemon-reload` |
| Thay đổi cây không hiện sang người khác | nginx thiếu `location /cable`, hoặc gem `redis` lên 6.x (actioncable 7.2 yêu cầu `< 6`) | Kiểm tra vhost; giữ `gem "redis", "~> 5.4"` trong Gemfile |
| Email không tới | Chưa có `SMTP_*` trong `shared/.env` — production đang `delivery_method = :logger` | Điền SMTP rồi `systemctl --user reload xstudio_puma_production` |
| Nút ✨ hiện “AI chưa cấu hình” | Thiếu `ANTHROPIC_API_KEY` | Điền vào `shared/.env`, reload puma |
