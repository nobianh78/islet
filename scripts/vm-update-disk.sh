#!/usr/bin/env bash
# Chép bản Islet mới nhất (shell, cấu hình Hyprland, theme, icon, Firefox) vào ổ ảo đã cài
# (out/disk.qcow2) mà không cần cài lại. Máy ảo phải đang TẮT.
#   ./scripts/vm-update-disk.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"
DISK="$OUT/disk.qcow2"

[ -f "$DISK" ] || { echo "Không có $DISK" >&2; exit 1; }
if pgrep -x qemu-system-x86 >/dev/null; then echo "Tắt máy ảo trước đã." >&2; exit 1; fi

python3 "$ROOT/scripts/make-icons.py" >/dev/null

echo "==> Mở ổ ảo"
qemu-img convert -O raw "$DISK" "$OUT/disk.raw"
# vị trí phân vùng 2 (hệ thống) trong bảng GPT
OFF=$(python3 - "$OUT/disk.raw" <<'E'
import struct, sys
f = open(sys.argv[1], "rb"); f.seek(512); h = f.read(92)
lba, n, sz = struct.unpack("<Q", h[72:80])[0], struct.unpack("<I", h[80:84])[0], struct.unpack("<I", h[84:88])[0]
f.seek(lba * 512); parts = []
for _ in range(n):
    e = f.read(sz); first = struct.unpack("<Q", e[32:40])[0]
    if first: parts.append(first * 512)
print(parts[1])
E
)

echo "==> Chép bản mới"
docker run --rm --privileged -v "$ROOT:/src:ro" -v "$OUT:/out" archlinux:latest bash -euo pipefail -c "
    mkdir -p /r && mount -o loop,offset=$OFF /out/disk.raw /r
    U=\$(awk -F: '\$3==1000{print \$1}' /r/etc/passwd); H=/r/home/\$U; ID=1000
    echo \"    người dùng: \$U\"
    rm -rf /r/usr/share/islet/shell && cp -a /src/shell /r/usr/share/islet/shell
    mkdir -p /r/usr/share/islet/hypr /r/usr/share/islet/firefox \$H/.config/hypr \$H/.config/gtk-3.0 \$H/.config/gtk-4.0
    cp /src/hypr/hyprland.lua /r/usr/share/islet/hypr/ && cp /src/hypr/hyprland.lua \$H/.config/hypr/hyprland.lua
    cp -a /src/iso/islet/airootfs/etc/xdg/. /r/etc/xdg/
    cp /src/theme/gtk/gtk4.css \$H/.config/gtk-4.0/gtk.css && cp /src/theme/gtk/gtk3.css \$H/.config/gtk-3.0/gtk.css
    rm -rf /r/usr/share/icons/Islet && cp -a /src/theme/icons/Islet /r/usr/share/icons/Islet
    cp /src/theme/firefox/userChrome.css /r/usr/share/islet/firefox/
    install -m755 /src/iso/islet/airootfs/usr/local/bin/islet-firefox-theme /r/usr/local/bin/
    install -m755 /src/iso/islet/airootfs/usr/local/bin/islet-demo /r/usr/local/bin/
    install -m755 /src/iso/islet/airootfs/usr/local/bin/islet-pkg /r/usr/local/bin/
    install -m755 /src/iso/islet/airootfs/usr/local/bin/islet-ipc /r/usr/local/bin/
    install -m755 /src/iso/islet/airootfs/usr/local/bin/islet-wifi /r/usr/local/bin/
    cp /src/iso/islet/airootfs/usr/share/applications/islet-installer.desktop /r/usr/share/applications/
    cp /src/iso/islet/airootfs/usr/share/applications/islet-store.desktop /src/iso/islet/airootfs/usr/share/applications/islet-settings.desktop /r/usr/share/applications/
    mkdir -p /r/usr/lib/firefox/defaults/pref && cp /src/iso/islet/airootfs/usr/lib/firefox/defaults/pref/islet.js /r/usr/lib/firefox/defaults/pref/
    ln -sfn /usr/share/zoneinfo/Asia/Ho_Chi_Minh /r/etc/localtime
    # cấu hình cho lập trình
    A=/src/iso/islet/airootfs
    cp \$A/etc/sysctl.d/90-islet-dev.conf /r/etc/sysctl.d/ && cp \$A/etc/systemd/zram-generator.conf /r/etc/systemd/
    mkdir -p /r/etc/makepkg.conf.d && cp \$A/etc/makepkg.conf.d/islet.conf /r/etc/makepkg.conf.d/
    cp \$A/home/islet/.bashrc \$H/.bashrc && cp \$A/home/islet/.config/starship.toml \$H/.config/starship.toml
    chown -R \$ID:\$ID \$H/.config
    sync; umount /r
"

echo "==> Đóng ổ ảo"
qemu-img convert -O qcow2 "$OUT/disk.raw" "$DISK"
rm -f "$OUT/disk.raw"
echo "Xong. Boot: ISLET_BOOT=disk ./scripts/run-vm.sh"
