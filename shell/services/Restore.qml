pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Điểm khôi phục (snapshot Btrfs + snapper) — "bảo hiểm" của Islet.
//   supported : máy cài Btrfs có snapper
//   snaps     : [{ number, date, type (single|pre|post), description, when (chữ dễ đọc) }], mới nhất trước
//   booted    : đang chạy từ điểm khôi phục số mấy (chọn ở menu khởi động; 0 = hệ thống bình thường)
//   lastUpdate: điểm "trước bản cập nhật" gần nhất (nút "Undo the last update")
Singleton {
    id: root

    property bool supported: false
    property bool checked: false
    property var snaps: []
    property int booted: 0
    property string msg: ""
    property bool needsRestart: false
    readonly property var lastUpdate: snaps.find(s => s.type === "pre") ?? null
    readonly property var bootedSnap: snaps.find(s => s.number === booted) ?? null

    signal bootedIntoSnapshot(int n)

    // "Today 14:20" · "Yesterday 09:05" · "Tue 3 Nov 18:00"
    function when(date) {
        const d = new Date(String(date).replace(" ", "T"));
        if (isNaN(d)) return String(date);
        const day = new Date(d); day.setHours(0, 0, 0, 0);
        const today = new Date(); today.setHours(0, 0, 0, 0);
        const diff = Math.round((today - day) / 86400000);
        const t = Qt.formatTime(d, "HH:mm");
        return diff === 0 ? "Today " + t : diff === 1 ? "Yesterday " + t : Qt.formatDate(d, "ddd d MMM") + " " + t;
    }
    function label(s) {
        if (!s) return "";
        const d = s.description || "";
        if (s.type === "pre") return "Before " + (d.replace(/^pacman -\S+\s*/, "").split(" ").slice(0, 3).join(", ") || "an update");
        if (s.type === "post") return "After an update";
        return d || "Restore point " + s.number;
    }

    Component.onCompleted: probe.running = true
    Process {
        id: probe
        command: ["sh", "-c", "findmnt -no FSTYPE /; command -v snapper >/dev/null && echo snapper; islet-snapshot-boot status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.supported = l[0].trim() === "btrfs" && l.indexOf("snapper") >= 0;
                try { root.booted = JSON.parse(l.find(x => x.startsWith("{")) || "{}").booted || 0; } catch (e) {}
                root.checked = true;
                if (root.booted > 0) { root.refresh(); boot.start(); }
            }
        }
    }
    Timer { id: boot; interval: 6000; onTriggered: root.bootedIntoSnapshot(root.booted) }

    function refresh() {
        if (!supported) return;
        Admin.run(["snapshot", "list"], (ok, out) => {
            if (!ok) { msg = out; return; }
            try {
                const d = JSON.parse(out); const l = d.root || d[Object.keys(d)[0]] || [];
                snaps = l.filter(x => x.number > 0).reverse().map(x => Object.assign({}, x, { when: when(x.date) }));
            } catch (e) { msg = "Couldn't read restore points"; }
        });
    }
    function create(desc) {
        Admin.run(["snapshot", "create", Qt.btoa(desc)], (ok, out) => { msg = ok ? "Restore point created" : out; refresh(); });
    }
    function remove(n) {
        Admin.run(["snapshot", "delete", String(n)], (ok, out) => { msg = ok ? "" : out; refresh(); });
    }
    // quay hệ thống về điểm n (file trong thư mục nhà giữ nguyên) — xong phải khởi động lại
    function restore(n, cb) {
        Admin.run(["snapshot", "rollback", String(n)], (ok, out) => {
            needsRestart = ok;
            msg = ok ? "Restart to finish going back" : out;
            if (cb) cb(ok);
        });
    }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]); }
}
