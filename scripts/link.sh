#!/usr/bin/env bash
# Liên kết cấu hình Islet vào ~/.config để Hyprland dùng được (không ghi đè file sẵn có).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p ~/.config/islet ~/.config/hypr
ln -sfn "$ROOT/shell" ~/.config/islet/shell
if [ -e ~/.config/hypr/hyprland.conf ] && [ ! -L ~/.config/hypr/hyprland.conf ]; then
    echo "Đã có ~/.config/hypr/hyprland.conf, giữ nguyên. Cấu hình Islet ở: $ROOT/hypr/hyprland.conf"
else
    ln -sfn "$ROOT/hypr/hyprland.conf" ~/.config/hypr/hyprland.conf
fi
echo "Xong. Đăng xuất, chọn phiên Hyprland ở màn hình đăng nhập."
