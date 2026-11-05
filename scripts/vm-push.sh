#!/usr/bin/env bash
# Đẩy bản Islet mới vào máy ảo ĐANG CHẠY (đã cài vào ổ) qua SSH rồi khởi động lại shell.
#   ISLET_SUDO_PASS=<mật khẩu người dùng trong máy ảo> ./scripts/vm-push.sh
# Mật khẩu chỉ đi qua stdin của sudo, không ghi ra đâu.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
U=${ISLET_VM_USER:-nguyentuananh}
O=(-p 2222 -i "$ROOT/out/dev_key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
: "${ISLET_SUDO_PASS:?đặt ISLET_SUDO_PASS}"
A=iso/islet/airootfs
python3 "$ROOT/scripts/make-icons.py" >/dev/null
tar -C "$ROOT" -cf - shell hypr/hyprland.lua theme/icons/Islet $A/usr/local/bin $A/usr/share/applications $A/usr/local/share/applications \
    | ssh "${O[@]}" "$U@localhost" 'rm -rf /tmp/up && mkdir /tmp/up && tar -C /tmp/up -xf -'
printf '%s\n' "$ISLET_SUDO_PASS" | ssh "${O[@]}" "$U@localhost" 'sudo -S -p "" sh -c "
    set -e; U=/tmp/up; A=\$U/iso/islet/airootfs
    rm -rf /usr/share/islet/shell && cp -a \$U/shell /usr/share/islet/shell
    mkdir -p /usr/share/islet/hypr && cp \$U/hypr/hyprland.lua /usr/share/islet/hypr/
    rm -rf /usr/share/icons/Islet && cp -a \$U/theme/icons/Islet /usr/share/icons/Islet
    install -m755 \$A/usr/local/bin/* /usr/local/bin/
    install -m644 \$A/usr/share/applications/*.desktop /usr/share/applications/
    mkdir -p /usr/local/share/applications && install -m644 \$A/usr/local/share/applications/*.desktop /usr/local/share/applications/
    chown -R root:root /usr/share/islet /usr/share/icons/Islet
"'
ssh "${O[@]}" "$U@localhost" 'cp /tmp/up/hypr/hyprland.lua ~/.config/hypr/hyprland.lua; rm -rf /tmp/up ~/.config/islet/shell
    export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$(id -u)/hypr | head -1)
    hyprctl reload >/dev/null 2>&1 || true
    # chạy lại shell QUA Hyprland để nó có đúng môi trường của phiên (XDG_SESSION_TYPE=wayland…);
    # chạy thẳng từ SSH thì app mở từ dock nhận môi trường tty và không hiện cửa sổ được
    pkill -x qs || true; sleep 1
    hyprctl dispatch "hl.dsp.exec_cmd(\"qs -p /usr/share/islet/shell >/tmp/qs.log 2>&1\")" >/dev/null; sleep 3
    grep -E "ERROR|error|Loaded" /tmp/qs.log | grep -v bluez | head -20'
