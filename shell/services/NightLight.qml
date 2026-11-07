pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Night Light: giảm ánh xanh (hyprsunset). Bật / tắt / theo giờ (Prefs.nightFrom → nightTo).
// Chuyển dần trong ~40 giây (hyprctl hyprsunset temperature …) cho mắt không thấy giật.
Singleton {
    id: root

    property real now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = Date.now() }

    function mins(hhmm) { const p = (hhmm || "0:0").split(":"); return (+p[0] || 0) * 60 + (+p[1] || 0); }
    readonly property bool inSchedule: {
        const d = new Date(now), m = d.getHours() * 60 + d.getMinutes();
        const a = mins(Prefs.nightFrom), b = mins(Prefs.nightTo);
        return a <= b ? (m >= a && m < b) : (m >= a || m < b);
    }
    readonly property bool active: Prefs.nightMode === "on" || (Prefs.nightMode === "schedule" && inSchedule)
    readonly property int target: active ? Prefs.nightTemp : 6500

    property int current: 6500
    onTargetChanged: ramp.restart()
    Component.onCompleted: ramp.restart()

    // hyprsunset chạy nền khi cần; nhiệt độ đổi qua IPC của nó
    Process {
        id: sun
        command: ["hyprsunset", "-t", "6500"]
        onExited: root.current = 6500
    }
    Timer {
        id: ramp
        interval: 400
        repeat: true
        onTriggered: {
            if (root.target < 6500 && !sun.running) { sun.running = true; return; }
            const step = root.target < root.current ? -60 : 60;
            if (Math.abs(root.target - root.current) <= 60) root.current = root.target;
            else root.current += step;
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.current)]);
            if (root.current === root.target) {
                stop();
                if (root.target >= 6500 && sun.running) sun.running = false;
            }
        }
    }
    // hình nền ban đêm dùng cùng khung giờ
    Binding { target: Prefs; property: "nightNow"; value: root.inSchedule }
    function toggle() { Prefs.set("nightMode", active ? "off" : "on"); }
}
