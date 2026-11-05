#!/usr/bin/env bash
# Chụp màn hình máy ảo qua SSH → out/<tên>.png    ./scripts/vm-shot.sh tên [vùng "x,y wxh"] [lệnh chạy trước]
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
O=(-p 2222 -i "$ROOT/out/dev_key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
U=${ISLET_VM_USER:-nguyentuananh}
ssh "${O[@]}" "$U@localhost" "export LANG=C.UTF-8 XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=\$(ls /run/user/1000/hypr | head -1); ${3:-true} >/dev/null 2>&1; sleep ${SLEEP:-1.5}; grim ${2:+-g \"$2\"} /tmp/shot.png"
scp -P 2222 -i "$ROOT/out/dev_key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$U@localhost:/tmp/shot.png" "$ROOT/out/$1.png"
