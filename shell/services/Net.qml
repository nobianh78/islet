pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Trạng thái mạng, đọc thẳng từ /sys và /proc mỗi 4 giây (không phụ thuộc NetworkManager).
//   kind: "wifi" | "ethernet" | "none"
Singleton {
    id: root

    property string kind: "none"
    property string name: ""
    property real strength: 0      // 0..1 với Wi-Fi
    property bool wifiPresent: false
    property bool wifiBlocked: false
    property bool airplane: false          // mọi thiết bị vô tuyến (Wi-Fi, Bluetooth…) đang bị chặn

    readonly property bool connected: kind !== "none"
    readonly property string icon: kind === "wifi" ? "wifi" : kind === "ethernet" ? "ethernet" : "wifi-off"
    readonly property string label: kind === "wifi" ? (name || "Wi-Fi")
        : kind === "ethernet" ? "Wired"
        : wifiBlocked ? "Off" : "Not connected"

    function refresh() { if (!probe.running) probe.running = true; }

    function toggleWifi() {
        Quickshell.execDetached(["rfkill", wifiBlocked ? "unblock" : "block", "wlan"]);
        delay.restart();
    }

    function toggleAirplane() {
        Quickshell.execDetached(["rfkill", airplane ? "unblock" : "block", "all"]);
        delay.restart();
    }

    Timer { id: delay; interval: 800; onTriggered: root.refresh() }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    // In ra một dòng: kind|name|strength|wifiPresent|wifiBlocked
    Process {
        id: probe
        command: ["sh", "-c", `
            kind=none; name=; q=0; wp=0; wb=0; ab=0
            for d in /sys/class/net/*; do
                i=\${d##*/}; [ "$i" = lo ] && continue
                if [ -d "$d/wireless" ]; then
                    wp=1
                    if [ "$(cat $d/operstate 2>/dev/null)" = up ]; then
                        kind=wifi
                        q=$(awk -v i="$i:" '$1==i {print int($3)}' /proc/net/wireless)
                        name=$(iw dev "$i" link 2>/dev/null | sed -n 's/^\\s*SSID: //p')
                    fi
                elif [ "$kind" = none ] && [ "$(cat $d/operstate 2>/dev/null)" = up ] && [ ! -e "$d/bridge" ]; then
                    case "$i" in veth*|docker*|virbr*|br-*) ;; *) kind=ethernet ;; esac
                fi
            done
            rfkill -n -o TYPE,SOFT list 2>/dev/null | grep -q "^wlan *blocked" && wb=1
            s=$(rfkill -n -o SOFT list 2>/dev/null); [ -n "$s" ] && ! echo "$s" | grep -q "^unblocked" && ab=1
            echo "$kind|$name|\${q:-0}|$wp|$wb|$ab"
        `]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split("|");
                root.kind = p[0];
                root.name = p[1];
                root.strength = Math.min(1, (parseInt(p[2]) || 0) / 70);
                root.wifiPresent = p[3] === "1";
                root.wifiBlocked = p[4] === "1";
                root.airplane = p[5] === "1";
            }
        }
    }
}
