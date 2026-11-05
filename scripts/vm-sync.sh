#!/usr/bin/env bash
# Đẩy shell/ vào máy ảo đang chạy (ISO build với ISLET_DEV=1) và chạy lại Quickshell.
#   ./scripts/vm-sync.sh         đồng bộ + khởi động lại shell, in log
#   ./scripts/vm-sync.sh log     chỉ xem log
#   ./scripts/vm-sync.sh -- CMD  chạy lệnh trong phiên Hyprland của máy ảo
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS=(-i "$ROOT/out/dev_key" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
S() { ssh "${SSH_OPTS[@]}" islet@localhost "$@"; }

# Biến môi trường để lệnh chạy được trong phiên Hyprland của máy ảo.
ENV='export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=$(basename $(ls /run/user/1000/wayland-* | grep -v lock | head -1))
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1)
export QT_QPA_PLATFORM=wayland DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus'

R() { rsync -a -e "ssh ${SSH_OPTS[*]}" "$@"; }

case "${1:-sync}" in
    setup)
        # Đưa những thứ mới hơn ISO đang chạy vào máy ảo: config Hyprland, theme kitty + GTK, giờ.
        R "$ROOT/hypr/hyprland.lua" islet@localhost:.config/hypr/hyprland.lua
        R "$ROOT/iso/islet/airootfs/etc/xdg/kitty/" islet@localhost:.config/kitty/
        S "mkdir -p ~/.config/gtk-4.0 ~/.config/gtk-3.0"
        R "$ROOT/theme/gtk/gtk4.css" islet@localhost:.config/gtk-4.0/gtk.css
        R "$ROOT/theme/gtk/gtk3.css" islet@localhost:.config/gtk-3.0/gtk.css
        R "$ROOT/theme/firefox/userChrome.css" "$ROOT/iso/islet/airootfs/usr/local/bin/islet-firefox-theme" \
            "$ROOT/iso/islet/airootfs/usr/lib/firefox/defaults/pref/islet.js" islet@localhost:/tmp/
        S "sudo mkdir -p /usr/share/islet/firefox && sudo cp /tmp/userChrome.css /usr/share/islet/firefox/ && sudo install -m755 /tmp/islet-firefox-theme /usr/local/bin/ && sudo cp /tmp/islet.js /usr/lib/firefox/defaults/pref/ && islet-firefox-theme"
        S "mkdir -p ~/.local/share/icons"
        R --delete "$ROOT/theme/icons/Islet" islet@localhost:.local/share/icons/
        S "$ENV
sudo ln -sfn /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
command -v grim >/dev/null || sudo pacman -Sy --noconfirm grim >/dev/null 2>&1
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
gsettings set org.gnome.desktop.interface icon-theme 'Islet'
hyprctl reload >/dev/null; echo setup xong"
        exec "$0" sync
        ;;
    log)
        S 'f=$(ls -t /run/user/1000/quickshell/by-id/*/log.log | head -1); cut -c1-400 "$f" | tail -40'
        ;;
    --)
        shift
        S "$ENV; $*"
        ;;
    sync)
        rsync -a --delete -e "ssh ${SSH_OPTS[*]}" "$ROOT/shell/" islet@localhost:islet-shell/
        S "$ENV
pkill -x qs 2>/dev/null; pkill -x quickshell 2>/dev/null; sleep 0.5
setsid -f qs -p ~/islet-shell >/dev/null 2>&1 < /dev/null
sleep 4
f=\$(ls -t /run/user/1000/quickshell/by-id/*/log.log | head -1); cut -c1-400 \"\$f\" | tail -30
pgrep -x qs >/dev/null && echo '== qs đang chạy' || echo '== qs đã thoát'"
        ;;
esac
