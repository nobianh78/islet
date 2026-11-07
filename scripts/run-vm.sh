#!/usr/bin/env bash
# Boot ISO Islet mới nhất trong QEMU (KVM + GPU ảo virgl để Hyprland chạy được).
#   ./scripts/run-vm.sh [đường-dẫn.iso]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:-$(ls -t "$ROOT"/out/islet-*.iso 2>/dev/null | head -1)}"
[ -f "$ISO" ] || { echo "Không thấy ISO. Chạy ./scripts/build-iso.sh trước." >&2; exit 1; }

# UEFI (OVMF) để boot qua systemd-boot như máy thật
VARS=${ISLET_VARS:-"$ROOT/out/OVMF_VARS.fd"}
[ -f "$VARS" ] || cp /usr/share/OVMF/OVMF_VARS_4M.fd "$VARS"

# Ổ ảo để thử trình cài đặt: ISLET_DISK=1 → gắn out/disk.qcow2 (20 GB, tạo nếu chưa có)
#                            ISLET_BOOT=disk → boot thẳng từ ổ đã cài (không gắn ISO)
#   ISLET_DISK_FILE=out/khac.qcow2 / ISLET_VARS=out/khac_VARS.fd → thử cài vào ổ khác mà không đụng ổ chính
DISKF=${ISLET_DISK_FILE:-"$ROOT/out/disk.qcow2"}
EXTRA=()
if [ "${ISLET_DISK:-0}" = 1 ] || [ "${ISLET_BOOT:-}" = disk ]; then
    [ -f "$DISKF" ] || qemu-img create -q -f qcow2 "$DISKF" 20G
    # bootindex: boot từ ổ này trước (khi không gắn ISO), thay vì để firmware thử PXE
    EXTRA+=(-drive file="$DISKF",if=none,id=hd0,format=qcow2 -device virtio-blk-pci,drive=hd0,bootindex=1)
fi
MEDIA=(-drive file="$ISO",media=cdrom,if=none,id=cd0,readonly=on -device ide-cd,drive=cd0,bootindex=0)
[ "${ISLET_BOOT:-}" = disk ] && MEDIA=()

echo "Boot $ISO"
exec qemu-system-x86_64 \
    -enable-kvm -cpu host -machine q35 \
    -smp 4 -m 4096 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="$VARS" \
    "${MEDIA[@]}" "${EXTRA[@]}" \
    -device virtio-vga-gl,xres=1440,yres=900 \
    -display gtk,gl=on,zoom-to-fit=off \
    -device virtio-tablet-pci -device virtio-keyboard-pci \
    -audiodev pipewire,id=snd -device intel-hda -device hda-duplex,audiodev=snd \
    -netdev user,id=net,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net \
    -qmp unix:"$ROOT/out/qmp.sock",server=on,wait=off \
    -serial file:"$ROOT/out/serial.log"
