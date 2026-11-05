pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Độ sáng màn hình qua brightnessctl. Máy không có đèn nền (máy bàn, máy ảo) thì available = false.
Singleton {
    id: root

    property bool available: false
    property real value: 0.8

    function set(v) {
        v = Math.max(0.02, Math.min(1, v));
        value = v;
        Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(v * 100) + "%"]);
    }

    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: SplitParser {
            // backlight-device,backlight,current,percent%,max
            onRead: line => {
                const p = line.split(",");
                if (p.length >= 5) {
                    root.available = true;
                    root.value = parseInt(p[2]) / parseInt(p[4]);
                }
            }
        }
    }
}
