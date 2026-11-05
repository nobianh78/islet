#!/usr/bin/env bash
# Liên kết cấu hình Islet vào ~/.config để Hyprland dùng được (không ghi đè file sẵn có).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p ~/.config/islet ~/.config/hypr
ln -sfn "$ROOT/shell" ~/.config/islet/shell
if [ -e ~/.config/hypr/hyprland.lua ] && [ ! -L ~/.config/hypr/hyprland.lua ]; then
    echo "Đã có ~/.config/hypr/hyprland.lua, giữ nguyên. Cấu hình Islet ở: $ROOT/hypr/hyprland.lua"
else
    ln -sfn "$ROOT/hypr/hyprland.lua" ~/.config/hypr/hyprland.lua
fi
echo "Xong. Đăng xuất, chọn phiên Hyprland ở màn hình đăng nhập."
