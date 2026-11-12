#!/usr/bin/env bash
# Kiểm tra shell Islet trong máy ảo ĐANG CHẠY (không cần sudo): nạp shell, mở từng cửa sổ / trang cài đặt,
# rồi tìm lỗi QML trong log. Thoát khác 0 nếu có lỗi mới (ngoài scripts/test-shell.allow).
#   ./scripts/test-shell.sh
# Không khoá màn hình (khoá cần mật khẩu để mở). Chạy xong shell hệ thống được bật lại.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
O=(-p 2222 -i "$ROOT/out/dev_key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=8)
U=${ISLET_VM_USER:-nguyentuananh}
S() { timeout "${2:-90}" ssh "${O[@]}" "$U@localhost" "export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=\$(ls /run/user/1000/hypr | head -1); $1" 2>&1 | grep -v 'locale\|Qt depends\|more information'; }

timeout 15 ssh "${O[@]}" "$U@localhost" true >/dev/null 2>&1 || { echo "Không SSH được vào máy ảo (chạy ISLET_BOOT=disk ./scripts/run-vm.sh trước)" >&2; exit 2; }
echo "==> Đẩy shell vào ~/shtest"
tar -C "$ROOT" -cf - shell | ssh "${O[@]}" "$U@localhost" 'rm -rf ~/shtest && mkdir ~/shtest && tar -C ~/shtest --strip-components=1 -xf -'
PAGES=$(grep -o 'id: "[a-z-]*", *g:' "$ROOT/shell/settings/Settings.qml" | grep -o '"[a-z-]*"' | tr -d '"' | tr '\n' ' ')

echo "==> Nạp shell và mở từng cửa sổ"
S "pkill -x qs; sleep 1; (setsid qs -p ~/shtest >/tmp/qs-test.log 2>&1 </dev/null &); sleep 10; pgrep -x qs >/dev/null || echo SHELL-DEAD
Q() { timeout 8 qs -p ~/shtest ipc call \"\$@\" >/dev/null 2>&1; sleep 1.2; }
for t in cc launcher taskmgr search notifs power; do Q \$t toggle; Q \$t toggle; done
for p in $PAGES; do Q settings page \$p; done
Q settings toggle
Q island open now; Q island open timer; Q island open clipboard; Q island open calendar; Q island toggle
Q store open; Q trash open; Q backup open; Q welcome open; Q focus on; Q focus off
sleep 2; pgrep -x qs >/dev/null && echo SHELL-ALIVE || echo SHELL-DEAD" 400 | tee /tmp/test-shell.out | grep -E "SHELL-"

echo "==> Đọc log"
S 'cat /tmp/qs-test.log' 30 > /tmp/test-shell.log
PAT='ERROR|TypeError|ReferenceError|is not a type|unavailable|Cannot override|Invalid property|Binding loop|Unable to assign|fatal error|invalid object'
ALLOW="$ROOT/scripts/test-shell.allow"
sed 's/\x1b\[[0-9;]*m//g' /tmp/test-shell.log | grep -E "$PAT" | { [ -f "$ALLOW" ] && grep -vEf "$ALLOW" || cat; } | sort -u > /tmp/test-shell.bad

echo "==> Bật lại shell hệ thống"
S 'pkill -x qs; sleep 1; hyprctl dispatch "hl.dsp.exec_cmd(\"qs -p /usr/share/islet/shell >/tmp/qs.log 2>&1\")" >/dev/null; sleep 3; pgrep -x qs >/dev/null && echo restored' 40 | tail -1

if grep -q SHELL-DEAD /tmp/test-shell.out || [ -s /tmp/test-shell.bad ]; then
    echo "KHÔNG ĐẠT:"; grep -q SHELL-DEAD /tmp/test-shell.out && echo "  - shell bị thoát giữa chừng"; sed 's/^/  - /' /tmp/test-shell.bad; exit 1
fi
echo "ĐẠT: shell nạp được, mở hết cửa sổ và trang cài đặt, không có lỗi QML mới"
