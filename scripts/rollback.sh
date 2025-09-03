#!/usr/bin/env bash
# Rollback to a previous backup snapshot (created by deploy workflow)
# Usage:
#   scripts/rollback.sh           # ย้อนกลับไป snapshot ล่าสุด
#   scripts/rollback.sh --list    # แสดงรายชื่อ backups
#   scripts/rollback.sh --to 20250903-070000   # ระบุ timestamp (ไม่ต้องใส่ .tar.gz)
set -euo pipefail

PHP_BIN="${PHP_BIN:-/usr/local/php83/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-/usr/local/bin/composer}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"
WEB_GROUP="www-data"
OWNER_USER="admin"

cd "$PROJECT_ROOT"
mkdir -p "$BACKUP_DIR"

if [[ "${1:-}" == "--list" ]]; then
  echo "Available backups (newest first):"
  ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "(no backups found)"
  exit 0
fi

TARGET_FILE=""
if [[ "${1:-}" == "--to" ]]; then
  shift
  TS="${1:-}"
  [[ -z "$TS" ]] && { echo "ERROR: specify timestamp after --to"; exit 1; }
  if [[ -f "$BACKUP_DIR/$TS.tar.gz" ]]; then
    TARGET_FILE="$BACKUP_DIR/$TS.tar.gz"
  elif [[ -f "$TS" ]]; then
    TARGET_FILE="$TS"
  else
    echo "ERROR: backup not found: $TS" >&2
    exit 1
  fi
else
  TARGET_FILE="$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1 || true)"
  [[ -z "$TARGET_FILE" ]] && { echo "ERROR: no backups found in $BACKUP_DIR"; exit 1; }
fi

echo "==> Rolling back using: $TARGET_FILE"

TMP_DIR="$PROJECT_ROOT/rollback_tmp"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

tar -xzf "$TARGET_FILE" -C "$TMP_DIR"

rsync -a --delete \
  --exclude "storage" \
  --exclude ".env" \
  --exclude "backups" \
  --exclude ".git" \
  --exclude ".github" \
  "$TMP_DIR"/ ./

rm -rf "$TMP_DIR"

echo "==> Using PHP at: $PHP_BIN"
$PHP_BIN -v

$PHP_BIN "$COMPOSER_BIN" install --no-interaction --prefer-dist --no-dev

$PHP_BIN artisan optimize:clear
$PHP_BIN artisan config:cache
$PHP_BIN artisan route:cache
$PHP_BIN artisan view:cache
$PHP_BIN artisan queue:restart || true
$PHP_BIN artisan horizon:terminate || true

chown -R "$OWNER_USER":"$WEB_GROUP" . || true
find storage -type d -exec chmod 775 {} \; || true
find storage -type f -exec chmod 664 {} \; || true

echo "==> Rollback finished ✔"
