pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Micro / camera đang được dùng (chấm cam / chấm xanh trên island, kiểu iPhone).
//   micro : luồng ghi âm trong PipeWire · camera: tiến trình đang mở /dev/video*
Singleton {
    id: root

    readonly property var micStreams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio)
    PwObjectTracker { objects: root.micStreams }
    readonly property var micApps: {
        const names = micStreams.map(n => n.properties?.["application.name"] || n.properties?.["node.name"] || n.name || "An app")
            .filter(x => !/^(islet|quickshell|qs|wireplumber|pipewire)$/i.test(x));
        return names.filter((x, i) => names.indexOf(x) === i);
    }
    readonly property bool mic: micApps.length > 0

    property var camApps: []
    readonly property bool camera: camApps.length > 0
    Process {
        id: cam
        command: ["sh", "-c", 'for p in /proc/[0-9]*; do for f in "$p"/fd/*; do case "$(readlink "$f" 2>/dev/null)" in /dev/video*) cat "$p/comm"; break;; esac; done; done 2>/dev/null | sort -u']
        stdout: StdioCollector {
            onStreamFinished: root.camApps = text.split("\n").filter(x => x && !/^(pipewire|wireplumber|pipewire-media)$/.test(x))
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!cam.running) cam.running = true }

    signal started(string what, string app)
    // app nào đã dùng micro / camera (mới nhất trước, tối đa 20) — Cài đặt › Privacy
    property var history: []
    onStarted: (what, app) => { history = [{ what: what, app: app, time: Date.now() }].concat(history).slice(0, 20); }
    property bool _mic: false
    property bool _cam: false
    onMicChanged: { if (mic && !_mic) started("microphone", micApps[0]); _mic = mic; }
    onCameraChanged: { if (camera && !_cam) started("camera", camApps[0]); _cam = camera; }
}
