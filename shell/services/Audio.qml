pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Âm lượng loa mặc định qua PipeWire. Phát tín hiệu `touched` khi người dùng đổi âm lượng
// để island hiện thanh âm lượng.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property real micVolume: source?.audio?.volume ?? 0

    signal touched()

    PwObjectTracker { objects: (root.sink ? [root.sink] : []).concat(root.source ? [root.source] : []).concat(root.sinks) }

    // Bỏ qua các thay đổi trong lúc mới khởi động (lúc node vừa được bind).
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    onVolumeChanged: if (armed) touched()
    onMutedChanged: if (armed) touched()

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    function setMic(v) {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v));
    }
    // đổi sang loa / tai nghe kế tiếp
    function nextSink() {
        if (sinks.length < 2) return;
        const i = sinks.findIndex(n => n.id === sink?.id);
        Pipewire.preferredDefaultAudioSink = sinks[(i + 1) % sinks.length];
    }
}
