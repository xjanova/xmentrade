#!/usr/bin/env bash
# Quick push helper to GitHub main branch
set -euo pipefail
REPO_URL="${REPO_URL:-git@github.com:xjanova/xmentrade.git}"
BRANCH="${BRANCH:-main}"

git init
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"

git add .
git commit -m "${1:-update}" || true   # ถ้าไม่มีอะไรเปลี่ยนจะไม่คอมมิต
git push -u origin "$BRANCH"
echo "==> Pushed to $REPO_URL ($BRANCH) ✔"
