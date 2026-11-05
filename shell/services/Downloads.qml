pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// File đang tải trong ~/Downloads (Firefox: .part · Chromium/Chrome: .crdownload · Safari-kiểu: .download).
// Không biết tổng dung lượng nên island hiện số MB đã tải + tốc độ; xong thì báo "Downloaded".
Singleton {
    id: root

    property var items: []        // { name, size, speed }
    readonly property bool active: items.length > 0
    readonly property var top: items.length ? items[0] : null
    property var last: ({})       // tên tạm → { size, t }

    signal finished(string path, string name)

    function human(b) {
        if (b < 1e6) return Math.round(b / 1e3) + " KB";
        if (b < 1e9) return (b / 1e6).toFixed(b < 1e8 ? 1 : 0) + " MB";
        return (b / 1e9).toFixed(2) + " GB";
    }

    readonly property string dir: Quickshell.env("HOME") + "/Downloads"
    Process {
        id: scan
        command: ["sh", "-c", 'cd "$0" 2>/dev/null || exit 0; for f in *.part *.crdownload *.download; do [ -f "$f" ] && printf "%s\\t%s\\n" "$(stat -c %s "$f")" "$f"; done; exit 0', root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now(), seen = {}, out = [];
                for (const l of text.split("\n")) {
                    const t = l.indexOf("\t");
                    if (t < 0) continue;
                    const size = parseInt(l.slice(0, t)), tmp = l.slice(t + 1);
                    const prev = root.last[tmp];
                    const speed = prev ? Math.max(0, (size - prev.size) / Math.max(0.5, (now - prev.t) / 1000)) : 0;
                    seen[tmp] = { size: size, t: now, speed: prev ? (prev.speed * 0.5 + speed * 0.5) : 0 };
                    // Firefox tạo file tạm 0 byte cho tới khi bắt đầu tải → bỏ qua
                    if (size > 0) out.push({ name: tmp.replace(/\.(part|crdownload|download)$/, "").replace(/^\.?com\.google\.Chrome\.\w+$/, "download"), tmp: tmp, size: size, speed: seen[tmp].speed });
                }
                // file tạm biến mất → tải xong (nếu file thật có mặt)
                for (const tmp in root.last)
                    if (!seen[tmp] && root.last[tmp].size > 0) doneCheck.check(tmp.replace(/\.(part|crdownload|download)$/, ""));
                root.last = seen;
                root.items = out.sort((a, b) => b.size - a.size);
            }
        }
    }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: if (!scan.running) scan.running = true }

    QtObject {
        id: doneCheck
        function check(name) { finProc.name = name; finProc.running = true; }
    }
    Process {
        id: finProc
        property string name: ""
        command: ["test", "-f", root.dir + "/" + name]
        onExited: code => { if (code === 0) root.finished(root.dir + "/" + finProc.name, finProc.name); }
    }
}
