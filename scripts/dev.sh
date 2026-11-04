#!/usr/bin/env bash
# Chạy Islet shell từ mã nguồn (phải đang ở trong phiên Hyprland).
#   ./scripts/dev.sh          chạy shell, tự tải lại khi sửa file QML
#   ./scripts/dev.sh demo     thử lần lượt các chế độ của island
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHELL_DIR="$ROOT/shell"

if ! command -v qs >/dev/null; then
    echo "Chưa có Quickshell (lệnh qs). Xem README.md mục 'Chạy thử'." >&2
    exit 1
fi

case "${1:-run}" in
    run)
        exec qs -p "$SHELL_DIR"
        ;;
    demo)
        ipc() { qs -p "$SHELL_DIR" ipc call island "$@"; }
        echo "→ thông báo";   notify-send -a "Islet" "Chào mừng đến với Islet" "Dynamic Island đã sẵn sàng" || ipc test notif
        sleep 5.5
        echo "→ âm lượng";    ipc test volume; sleep 2
        echo "→ sạc pin";     ipc test battery; sleep 3.5
        echo "→ trình phát";  ipc toggle; sleep 4; ipc toggle
        ;;
    *)
        echo "Dùng: $0 [run|demo]" >&2; exit 2 ;;
esac
