#!/usr/bin/env bash
# Phát hành kho pacman [islet] lên GitHub Releases (bản phát hành có tag "repo").
# Máy Islet đã cài đọc kho ở  https://github.com/<repo>/releases/download/repo  (xem /etc/pacman.conf),
# nên chạy lệnh này xong là `pacman -Syu` / Cài đặt › Updates trên mọi máy thấy bản mới.
#   ./scripts/release-repo.sh            (cần: cây git sạch, gh đã đăng nhập, khoá ký Islet)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$ROOT/out/repo"
GH_REPO="${ISLET_GH_REPO:-nobianh78/islet}"
TAG=repo

ISLET_RELEASE=1 "$ROOT/scripts/build-packages.sh"

if ! gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
    gh release create "$TAG" -R "$GH_REPO" --target "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)" --latest=false \
        --title "Islet package repository" \
        --notes "pacman repository [islet] — do not download by hand. Installed Islet systems update from here with \`pacman -Syu\` (Settings › Updates)."
fi

cd "$REPO"
# gói trước, kho (islet.db) sau cùng: máy nào đang cập nhật giữa chừng cũng không thấy kho trỏ tới gói chưa có
echo "==> Tải gói lên"
gh release upload "$TAG" -R "$GH_REPO" --clobber ./*.pkg.tar.zst ./*.pkg.tar.zst.sig
echo "==> Tải kho lên"
gh release upload "$TAG" -R "$GH_REPO" --clobber islet.db islet.db.sig islet.db.tar.gz islet.db.tar.gz.sig \
    islet.files islet.files.sig islet.files.tar.gz islet.files.tar.gz.sig

echo "==> Dọn bản cũ"
gh release view "$TAG" -R "$GH_REPO" --json assets -q '.assets[].name' | while read -r n; do
    [ -e "$REPO/$n" ] || { echo "    xoá $n"; gh release delete-asset "$TAG" "$n" -R "$GH_REPO" -y; }
done
echo "Xong: https://github.com/$GH_REPO/releases/tag/$TAG"
