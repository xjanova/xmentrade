#!/usr/bin/env bash
# Deploy script for trade.xman4289.com (Laravel 12)
set -euo pipefail

PHP_BIN="${PHP_BIN:-/usr/local/php83/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-/usr/local/bin/composer}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_GROUP="www-data"
OWNER_USER="admin"

cd "$PROJECT_ROOT"

echo "==> Using PHP at: $PHP_BIN"
$PHP_BIN -v

if [ ! -x "$COMPOSER_BIN" ]; then
  if command -v composer >/dev/null 2>&1; then
    COMPOSER_BIN="$(command -v composer)"
  elif [ -f "$PROJECT_ROOT/composer.phar" ]; then
    COMPOSER_BIN="$PROJECT_ROOT/composer.phar"
  else
    echo "Composer not found. Set COMPOSER_BIN or install composer." >&2
    exit 1
  fi
fi
echo "==> Composer at: $COMPOSER_BIN"
$PHP_BIN "$COMPOSER_BIN" -V || true

chgrp -R "$WEB_GROUP" storage bootstrap/cache || true
chmod -R 775 storage bootstrap/cache || true

$PHP_BIN "$COMPOSER_BIN" install --no-interaction --prefer-dist --no-dev

if ! grep -qE '^APP_KEY=base64:' .env 2>/dev/null; then
  $PHP_BIN artisan key:generate
fi

$PHP_BIN artisan migrate --force

$PHP_BIN artisan optimize:clear
$PHP_BIN artisan config:cache
$PHP_BIN artisan route:cache
$PHP_BIN artisan view:cache
$PHP_BIN artisan queue:restart || true
$PHP_BIN artisan horizon:terminate || true

chown -R "$OWNER_USER":"$WEB_GROUP" . || true
find storage -type d -exec chmod 775 {} \; || true
find storage -type f -exec chmod 664 {} \; || true

echo "==> Manual deploy finished ✔"
