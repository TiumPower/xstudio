#!/bin/bash
# Sao lưu hằng đêm cho Xstudio (NFR — Sao lưu).
#
#   CSDL   : dump mỗi đêm, giữ 30 ngày.
#   Tệp    : ActiveStorage lưu trên đĩa ở shared/storage. Nén mỗi CHỦ NHẬT,
#            giữ 8 bản (~2 tháng). Nén hằng ngày thì 30 bản nhân đôi dung
#            lượng mà chẳng thêm khả năng khôi phục bao nhiêu.
#
# Thiếu phần tệp thì mất đĩa là CSDL vẫn còn nhưng mọi ảnh và chứng từ đính
# kèm biến mất, trong khi bản ghi vẫn trỏ tới chúng.
set -euo pipefail

APP=/var/www/xstudio
DIR=$APP/shared/backups
ENVF=$APP/shared/.env
KEEP_DB=30
KEEP_FILES=8
STAMP=$(date +%Y-%m-%d_%H%M)

mkdir -p "$DIR"

get() { grep -E "^$1=" "$ENVF" | cut -d= -f2- | head -1; }
export PGPASSWORD="$(get DATABASE_PASSWORD)"
DB="$(get DATABASE_NAME)"
USER="$(get DATABASE_USER)"

# --- CSDL ------------------------------------------------------------------
pg_dump -h localhost -U "${USER:-xstudio}" "${DB:-xstudio_production}" | gzip > "$DIR/xstudio_$STAMP.sql.gz"
find "$DIR" -name 'xstudio_*.sql.gz' -mtime +$KEEP_DB -delete
echo "[$(date '+%F %T')] CSDL: xstudio_$STAMP.sql.gz ($(du -h "$DIR/xstudio_$STAMP.sql.gz" | cut -f1))"

# --- Tệp đính kèm ----------------------------------------------------------
STORAGE=$APP/shared/storage
if [ -d "$STORAGE" ] && [ -n "$(ls -A "$STORAGE" 2>/dev/null)" ]; then
  if [ "$(date +%u)" = "7" ] || [ ! -f "$DIR/.files_seen" ]; then
    tar -czf "$DIR/xstudio_files_$STAMP.tar.gz" -C "$APP/shared" storage
    touch "$DIR/.files_seen"
    ls -1t "$DIR"/xstudio_files_*.tar.gz 2>/dev/null | tail -n +$((KEEP_FILES + 1)) | xargs -r rm -f
    echo "[$(date '+%F %T')] Tệp:  xstudio_files_$STAMP.tar.gz ($(du -h "$DIR/xstudio_files_$STAMP.tar.gz" | cut -f1))"
  fi
else
  echo "[$(date '+%F %T')] Tệp:  chưa có tệp nào, bỏ qua"
fi
