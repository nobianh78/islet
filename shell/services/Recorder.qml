pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quay màn hình (wf-recorder) — island hiện chấm đỏ + thời gian; bấm island để dừng.
//   start(true): chọn vùng bằng slurp (Esc = cả màn hình) · start(false): cả màn hình
Singleton {
    id: root

    property bool recording: false
    property bool selecting: false
    property real startedAt: 0
    property string file: ""
    property real now: Date.now()
    Timer { interval: 500; running: root.recording; repeat: true; triggeredOnStart: true; onTriggered: root.now = Date.now() }
    readonly property string text: Chrono.fmt(Math.max(0, now - startedAt))

    signal saved(string path)

    function start(area) {
        if (recording || selecting) return;
        const d = new Date(), p = x => (x < 10 ? "0" : "") + x;
        file = Quickshell.env("HOME") + "/Videos/islet-recording-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
            + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + ".mp4";
        selecting = area;
        proc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$0")"; g=""; if [ "$1" = area ]; then g=$(slurp 2>/dev/null); fi; echo READY; ' +
            'if [ -n "$g" ]; then exec wf-recorder -y -f "$0" -g "$g"; else exec wf-recorder -y -f "$0"; fi',
            file, area ? "area" : "full"];
        proc.running = true;
    }
    function stop() { if (recording) Quickshell.execDetached(["pkill", "-INT", "-x", "wf-recorder"]); }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => { if (line === "READY") { root.selecting = false; root.recording = true; root.startedAt = Date.now(); } }
        }
        onExited: {
            const was = root.recording;
            root.recording = false;
            root.selecting = false;
            if (was) check.running = true;
        }
    }
    // có file thật thì báo đã lưu
    Process {
        id: check
        command: ["test", "-s", root.file]
        onExited: code => { if (code === 0) root.saved(root.file); }
    }
}
