#!/usr/bin/env bash
# Lấy icon THẬT (PNG 128px) của các app trong Cửa hàng (shell/store/Catalog.js) → shell/assets/store/<gói>.png
#   1. từ archlinux-appstream-data (icon .jxl 128px) nếu có
#   2. không thì mở chính gói của app: đọc Icon= trong .desktop rồi lấy icon hicolor / pixmaps
# Chạy trong container Arch nên máy chủ không cần gì thêm.   ./scripts/fetch-store-icons.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/shell/assets/store"
mkdir -p "$OUT" "$ROOT/out/cache/pkg"
PKGS=$(grep -oE 'pkg: *"[^"]+"' "$ROOT/shell/store/Catalog.js" | sed -E 's/.*"([^"]+)"/\1/' | grep -v '^stack:' | tr '\n' ' ')

docker run --rm -v "$OUT:/icons" -v "$ROOT/out/cache/pkg:/var/cache/pacman/pkg" \
    -e PKGS="$PKGS" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" archlinux:latest bash -euo pipefail -c '
    printf "Server = https://mirror.bizflycloud.vn/archlinux/\$repo/os/\$arch\nServer = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch\n" > /etc/pacman.d/mirrorlist
    pacman -Sy --noconfirm --needed archlinux-appstream-data imagemagick libjxl librsvg >/dev/null 2>&1
    AS=/usr/share/swcatalog/icons
    for p in $PKGS; do
        [ -s "/icons/$p.png" ] && continue
        # ưu tiên icon chính của app (vd. libreoffice → startcenter)
        f=$(ls $AS/archlinux-arch-*/128x128/${p}_*startcenter* 2>/dev/null | head -1 || true)
        [ -n "$f" ] || f=$(ls $AS/archlinux-arch-*/128x128/${p}_* 2>/dev/null | head -1 || true)
        if [ -n "$f" ]; then
            magick "$f" -resize 128x128 PNG32:"/icons/$p.png" && echo "appstream  $p"; continue
        fi
        # mở gói ra tìm icon
        # chỉ tải đúng gói của app (không kéo theo phụ thuộc, vd. 0ad-data 1.5 GB)
        pacman -Sw --noconfirm --nodeps --nodeps "$p" >/dev/null 2>&1 || { echo "không tải được $p"; continue; }
        pkgf=/var/cache/pacman/pkg/$(pacman -Sp --nodeps --nodeps --print-format "%f" "$p" 2>/dev/null | head -1)
        [ -f "$pkgf" ] || { echo "không thấy gói $p"; continue; }
        d=$(mktemp -d); bsdtar -xf "$pkgf" -C "$d" usr/share 2>/dev/null || true
        icon=$(grep -hm1 "^Icon=" "$d"/usr/share/applications/*.desktop 2>/dev/null | head -1 | cut -d= -f2 || true)
        [ -n "$icon" ] || icon=$p
        src=$(ls "$d"/usr/share/icons/hicolor/scalable/apps/${icon}.svg 2>/dev/null | head -1 || true)
        [ -n "$src" ] || src=$(ls -S "$d"/usr/share/icons/hicolor/*/apps/${icon}.png 2>/dev/null | head -1 || true)
        [ -n "$src" ] || src=$(ls "$d"/usr/share/pixmaps/${icon}.* 2>/dev/null | head -1 || true)
        if [ -n "$src" ]; then
            case "$src" in
                *.svg) rsvg-convert -w 128 -h 128 "$src" -o "/icons/$p.png" ;;
                *)     magick "$src" -resize 128x128 PNG32:"/icons/$p.png" ;;
            esac
            echo "trong gói  $p"
        else
            echo "KHÔNG CÓ   $p"
        fi
        rm -rf "$d"
    done
    chown -R "$HOST_UID:$HOST_GID" /icons
'
ls "$OUT" | wc -l
