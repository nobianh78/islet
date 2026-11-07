pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Lời bài hát chạy theo nhạc cho Dynamic Island (lấy bằng /usr/bin/islet-lyrics: LRCLIB + NetEase, có cache).
//   status : off | idle | loading | ok | none | error
//   index  : câu đang hát (-1 trước câu đầu) · current / progress: chữ + tiến độ karaoke của câu đó
//   offset : độ lệch riêng của bài (+ = hiện lời sớm hơn), chỉnh ở tab Now của island
Singleton {
    id: root

    readonly property bool enabled: Prefs.islandLyrics
    property string status: "idle"
    property var lines: []                 // [[giây, "câu"], …]
    property real offset: 0
    property int failures: 0

    // bài đang phát (đổi bài → tìm lời; nhiều trình phát báo tên trước, độ dài sau → đợi một nhịp)
    readonly property string title: Media.hasPlayer ? Media.title : ""
    readonly property string artist: Media.hasPlayer ? (Media.active?.trackArtist ?? "") : ""
    readonly property int length: Math.round(Media.length || 0)
    readonly property string key: enabled && title ? title + "\u0000" + artist + "\u0000" + length : ""
    onKeyChanged: {
        lines = []; offset = 0; failures = 0; retry.stop();
        status = !enabled ? "off" : key ? "loading" : "idle";
        if (key) settle.restart();
    }
    Timer { id: settle; interval: 700; onTriggered: root.fetch() }
    Timer { id: retry; onTriggered: root.fetch() }

    function fetch() {
        if (!key) return;
        proc.forKey = key;
        proc.command = ["islet-lyrics", "get", title, artist, String(length)];
        proc.running = true;
    }
    Process {
        id: proc
        property string forKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.forKey !== root.key) return;          // đã sang bài khác
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                if (!d) { root.status = "none"; return; }
                root.offset = Number(d.offset) || 0;
                root.lines = d.lines || [];
                root.status = d.state === "ok" && root.lines.length ? "ok" : d.state === "error" ? "error" : "none";
                if (root.status === "error") {               // mạng lỗi: thử lại sau 1, 2, 4 … 30 phút
                    root.failures++;
                    retry.interval = Math.min(30, Math.pow(2, root.failures - 1)) * 60000;
                    retry.restart();
                }
            }
        }
    }

    // ---- câu đang hát ----
    readonly property real pos: Media.position + offset
    readonly property int index: {
        const L = lines;
        if (status !== "ok" || !L.length) return -1;
        let lo = 0, hi = L.length - 1, ans = -1;
        const p = pos + 0.15;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (L[mid][0] <= p) { ans = mid; lo = mid + 1; } else hi = mid - 1;
        }
        return ans;
    }
    readonly property string current: index >= 0 ? (lines[index][1] || "") : ""
    readonly property real lineStart: index >= 0 ? lines[index][0] : 0
    readonly property real lineEnd: index >= 0 ? (index + 1 < lines.length ? lines[index + 1][0] : lineStart + 5) : 0
    // thời lượng câu cho karaoke (0,8…10 s: câu dài quá — đoạn nhạc dạo — thì sáng hết trong 10 s)
    readonly property real lineDur: Math.max(0.8, Math.min(10, lineEnd - lineStart))
    readonly property real elapsed: index < 0 ? 0 : Math.max(0, pos - lineStart)
    readonly property real progress: index < 0 ? 0 : Math.max(0, Math.min(1, elapsed / lineDur))
    // có câu để hiện trên island thu gọn
    readonly property bool showing: status === "ok" && current !== ""

    // ---- chỉnh tay ----
    Component { id: runner; Process {} }
    function run(args) {
        const p = runner.createObject(root, { command: ["islet-lyrics"].concat(args) });
        p.exited.connect(() => p.destroy());
        p.running = true;
    }
    function nudge(delta) {
        if (!key) return;
        offset = Math.round((offset + delta) * 10) / 10;
        run(["nudge", title, artist, String(length), String(delta)]);
    }
    function markWrong() {
        if (!key) return;
        run(["wrong", title, artist, String(length)]);
        lines = []; status = "none";
    }
}
