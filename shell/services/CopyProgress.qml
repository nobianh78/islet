pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Tiến độ copy file đang chạy (cp, mv, rsync, Files…) — island hiện "tên · 45% · còn 20 s".
// Việc quét do islet-copyprogress làm; ở đây tính tốc độ / thời gian còn lại và báo khi xong.
Singleton {
    id: root

    property var items: []        // { key, name, pos, size, frac, speed, eta }
    readonly property bool active: items.length > 0
    readonly property var top: items.length ? items[0] : null
    property var last: ({})       // key → { pos, t, speed }

    signal finished(string name)

    function human(b) {
        if (b < 1e6) return Math.round(b / 1e3) + " KB";
        if (b < 1e9) return (b / 1e6).toFixed(b < 1e8 ? 1 : 0) + " MB";
        return (b / 1e9).toFixed(2) + " GB";
    }
    function etaText(s) {
        if (!(s > 0) || !isFinite(s)) return "";
        if (s < 60) return Math.max(1, Math.round(s)) + " s left";
        if (s < 3600) return Math.round(s / 60) + " min left";
        return Math.floor(s / 3600) + " h " + Math.round(s % 3600 / 60) + " min left";
    }

    Process {
        id: scan
        command: ["islet-copyprogress"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = [];
                try { raw = JSON.parse(text || "[]"); } catch (e) {}
                const now = Date.now(), seen = {}, out = [];
                for (const c of raw) {
                    const key = c.pid + "|" + c.name;
                    const prev = root.last[key];
                    let speed = prev?.speed ?? 0;
                    if (prev && now > prev.t) {
                        const inst = Math.max(0, (c.pos - prev.pos) / ((now - prev.t) / 1000));
                        speed = speed > 0 ? speed * 0.6 + inst * 0.4 : inst;       // làm mượt để ETA không nhảy
                    }
                    seen[key] = { pos: c.pos, t: now, speed: speed, name: c.name, size: c.size };
                    out.push({ key: key, name: c.name, pos: c.pos, size: c.size, frac: c.pos / c.size, speed: speed,
                               eta: speed > 0 ? (c.size - c.pos) / speed : 0 });
                }
                // biến mất khi đã gần xong → báo hoàn tất (không báo nếu bị huỷ giữa chừng)
                for (const key in root.last)
                    if (!seen[key] && root.last[key].pos / root.last[key].size > 0.85) root.finished(root.last[key].name);
                root.last = seen;
                root.items = out.sort((a, b) => b.size - a.size);
            }
        }
    }
    Timer { interval: 1200; running: Prefs.islandLive; repeat: true; onTriggered: if (!scan.running) scan.running = true }
}
