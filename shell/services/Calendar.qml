pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ghi chú theo ngày, lưu ở ~/.local/share/islet/calendar.json
//   { "2026-11-04": [ { "id": 1730700000000, "text": "Họp nhóm", "time": "09:00", "done": false } ] }
// Ghi chú có giờ thì đến giờ phát tín hiệu `remind` để island bật nhắc.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/islet"
    readonly property string file: dir + "/calendar.json"

    property var notes: ({})
    property int version: 0          // tăng mỗi lần đổi, để binding cập nhật
    property bool loaded: false

    signal remind(var note)

    function key(d) {
        const p = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
    }

    function list(k) {
        version;
        const l = (notes[k] || []).slice();
        // có giờ lên trước (theo giờ), rồi tới ghi chú không giờ (theo lúc thêm)
        l.sort((a, b) => {
            if (a.time && b.time) return a.time.localeCompare(b.time);
            if (a.time) return -1;
            if (b.time) return 1;
            return a.id - b.id;
        });
        return l;
    }
    function count(k) { version; return (notes[k] || []).length; }
    function pending(k) { version; return (notes[k] || []).filter(n => !n.done).length; }

    // "9:00 Họp nhóm", "9h Họp", "14:30 Gọi mẹ" → tách giờ ra
    function parse(text) {
        const m = text.match(/^\s*(\d{1,2})(?:[:hg](\d{2})?)\s+(.+)$/i);
        if (m && +m[1] < 24 && (!m[2] || +m[2] < 60)) {
            const p = n => (n < 10 ? "0" : "") + n;
            return { time: p(+m[1]) + ":" + p(+(m[2] || 0)), text: m[3].trim() };
        }
        return { time: "", text: text.trim() };
    }

    function add(k, raw) {
        const r = parse(raw);
        if (!r.text) return;
        const l = (notes[k] || []).slice();
        l.push({ id: Date.now(), text: r.text, time: r.time, done: false });
        notes[k] = l;
        changed();
    }
    function remove(k, id) {
        notes[k] = (notes[k] || []).filter(n => n.id !== id);
        if (notes[k].length === 0) delete notes[k];
        changed();
    }
    function toggle(k, id) {
        notes[k] = (notes[k] || []).map(n => n.id === id ? Object.assign({}, n, { done: !n.done }) : n);
        changed();
    }

    function changed() {
        version++;
        saveTimer.restart();
    }

    // ---------------- lưu / đọc ----------------
    Process {
        id: mkdir
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: fileView.reload()
    }

    FileView {
        id: fileView
        path: root.file
        blockLoading: false
        onLoaded: {
            try { root.notes = JSON.parse(text() || "{}"); } catch (e) { root.notes = {}; }
            root.loaded = true;
            root.version++;
        }
        onLoadFailed: { root.loaded = true; }
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: fileView.setText(JSON.stringify(root.notes, null, 1))
    }

    // ---------------- nhắc giờ ----------------
    property var reminded: ({})
    Timer {
        interval: 20000
        repeat: true
        running: root.loaded
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            const k = root.key(now);
            const p = n => (n < 10 ? "0" : "") + n;
            const hm = p(now.getHours()) + ":" + p(now.getMinutes());
            for (const n of (root.notes[k] || [])) {
                if (!n.time || n.done || root.reminded[n.id]) continue;
                if (n.time === hm) {
                    root.reminded[n.id] = true;
                    root.remind(n);
                }
            }
        }
    }
}
