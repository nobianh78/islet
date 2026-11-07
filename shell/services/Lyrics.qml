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
    property real offset: 0                // chỉnh tay của bài (lưu trong cache)
    property real lrcDuration: 0           // độ dài bản nhạc mà lời được canh theo
    // MV trên YouTube thường có đoạn mở đầu trước khi vào nhạc → dài hơn bản lời vài giây: đẩy lời trễ lại
    // đúng phần chênh (2…45 s; chênh hơn thế là bản khác hẳn). Chỉnh tay cộng thêm vào.
    readonly property real autoOffset: {
        const d = songLen - lrcDuration;
        return lrcDuration > 0 && songLen > 0 && d > 2 && d <= 45 ? -d : 0;
    }
    property int failures: 0

    // Bài đang phát = tên + ca sĩ. Độ dài KHÔNG thuộc "bài nào": khi tua, nhiều trình phát (YouTube trong
    // trình duyệt…) gửi lại metadata — tên rỗng trong chốc lát, độ dài nhảy — nên chỉ coi là đổi bài khi
    // tên/ca sĩ khác hẳn và giữ khác ~0,9 s; quay về đúng bài đang có lời thì không tìm lại.
    readonly property string title: Media.hasPlayer ? Media.title : ""
    readonly property string artist: Media.hasPlayer ? (Media.active?.trackArtist ?? "") : ""
    readonly property string songId: enabled && title ? title + "\u0000" + artist : ""
    property string loadedId: ""          // bài đang giữ lời (hoặc đang tìm)
    property int songLen: 0               // độ dài dùng khi tìm (cũng là khoá cache của islet-lyrics)
    readonly property string key: loadedId
    onSongIdChanged: songChange.restart()
    onEnabledChanged: { loadedId = ""; songChange.restart(); }
    Timer { id: songChange; interval: 900; onTriggered: root.apply() }
    function apply() {
        if (songId === loadedId) return;                    // vẫn bài cũ (tua, metadata gửi lại…)
        lines = []; offset = 0; lrcDuration = 0; songLen = 0; lenWaits = 0; failures = 0; retry.stop();
        loadedId = songId;
        status = !enabled ? "off" : songId ? "loading" : "idle";
        if (songId) settle.restart();
    }
    // nhiều trình phát báo tên trước, độ dài sau → đợi thêm một nhịp rồi mới tìm
    Timer { id: settle; interval: 500; onTriggered: root.fetch() }
    Timer { id: retry; onTriggered: root.fetch() }

    // chưa biết độ dài (Firefox báo sau) → đợi thêm tối đa ~4 s rồi mới tìm, để còn so độ dài
    property int lenWaits: 0
    function fetch() {
        if (!loadedId) return;
        if (Math.round(Media.length || 0) <= 0 && lenWaits < 8) { lenWaits++; settle.restart(); return; }
        lenWaits = 0;
        songLen = Math.round(Media.length || 0);
        proc.forKey = loadedId;
        proc.command = ["islet-lyrics", "get", title, artist, String(songLen)];
        proc.running = true;
    }
    Process {
        id: proc
        property string forKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.forKey !== root.loadedId) return;     // đã sang bài khác
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                if (!d) { root.status = "none"; return; }
                root.offset = Number(d.offset) || 0;
                root.lrcDuration = Number(d.lrcDuration) || 0;
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
    // đã tìm lúc chưa có độ dài mà nay mới có → tìm lại (khoá cache khác, so được độ dài)
    readonly property int curLen: Math.round(Media.length || 0)
    onCurLenChanged: if (loadedId && songLen === 0 && curLen > 0 && !proc.running && status !== "loading") fetch()

    readonly property real pos: Media.position + offset + autoOffset
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
        run(["nudge", title, artist, String(songLen), String(delta)]);
    }
    function markWrong() {
        if (!key) return;
        run(["wrong", title, artist, String(songLen)]);
        lines = []; status = "none";
    }
}
