#!/bin/bash
# Sao lưu CSDL Xstudio hằng đêm, giữ 30 ngày (NFR — Sao lưu).
set -euo pipefail

DIR=/var/www/xstudio/shared/backups
KEEP=30
STAMP=$(date +%Y-%m-%d_%H%M)

mkdir -p "$DIR"
export PGPASSWORD="$(grep -E '^DATABASE_PASSWORD=' /var/www/xstudio/shared/.env | cut -d= -f2-)"
DB="$(grep -E '^DATABASE_NAME=' /var/www/xstudio/shared/.env | cut -d= -f2-)"
USER="$(grep -E '^DATABASE_USER=' /var/www/xstudio/shared/.env | cut -d= -f2-)"

pg_dump -h localhost -U "${USER:-xstudio}" "${DB:-xstudio_production}" | gzip > "$DIR/xstudio_$STAMP.sql.gz"

# Dọn bản cũ hơn KEEP ngày
find "$DIR" -name 'xstudio_*.sql.gz' -mtime +$KEEP -delete

echo "[$(date '+%F %T')] đã sao lưu xstudio_$STAMP.sql.gz ($(du -h "$DIR/xstudio_$STAMP.sql.gz" | cut -f1))"
