pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Time Machine của Islet: sao lưu thư mục nhà ra một ổ ngoài, giữ từng bản theo ngày (islet-backup).
// Chọn ổ một lần trong Cài đặt › Storage; từ đó cắm ổ vào là tự sao lưu (và mỗi giờ khi còn cắm).
Singleton {
    id: root

    property var drives: []                 // ổ ngoài đang cắm (islet-backup drives)
    readonly property var drive: drives.find(d => d.uuid === Prefs.backupDrive) ?? null
    readonly property bool connected: drive !== null
    readonly property string mount: drive?.mount ?? ""
    property bool running: false
    property int pct: 0
    property string error: ""
    property var list: []                   // các bản trên ổ đang chọn [{id, time}]
    readonly property var latest: list.length ? list[0] : null

    signal started(string label)
    signal finished(bool ok, string text)

    function when(ms) {
        if (!ms) return "Never";
        const d = new Date(ms);
        const day = new Date(d); day.setHours(0, 0, 0, 0);
        const today = new Date(); today.setHours(0, 0, 0, 0);
        const diff = Math.round((today - day) / 86400000);
        const t = Qt.formatTime(d, Prefs.clock24 ? "HH:mm" : "h:mm AP");
        return diff === 0 ? "Today " + t : diff === 1 ? "Yesterday " + t : Qt.formatDate(d, "d MMM yyyy") + " " + t;
    }
    function label(d) { return d ? (d.label || (d.dev ?? "").split("/").pop() || "Drive") : ""; }

    function choose(d) {
        Prefs.set("backupDrive", d.uuid);
        Prefs.set("backupLabel", label(d));
        refreshList();
    }
    function forget() { Prefs.set("backupDrive", ""); Prefs.set("backupLabel", ""); list = []; }

    // ---- ổ đang cắm (hỏi lại mỗi 10 giây — rẻ: chỉ là lsblk) ----
    Process {
        id: drv
        command: ["islet-backup", "drives"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = [];
                try { d = JSON.parse(text) || []; } catch (e) {}
                const was = root.connected;
                root.drives = d;
                if (root.connected && !was) root.arrived();
            }
        }
    }
    function refresh() { if (!drv.running) drv.running = true; }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    // ổ sao lưu vừa cắm vào: gắn nếu chưa gắn, rồi sao lưu nếu đã quá 1 giờ
    function arrived() {
        if (!drive.mount) { mounter.running = true; return; }
        refreshList();
        maybeAuto();
    }
    Process {
        id: mounter
        command: ["islet-backup", "mount", Prefs.backupDrive]
        onExited: root.refresh()
    }
    function maybeAuto() {
        if (Prefs.backupAuto && connected && mount && !running && Date.now() - Prefs.backupLast > 3600 * 1000) autoT.restart();
    }
    Timer { id: autoT; interval: 20000; onTriggered: if (Prefs.backupAuto && root.connected && root.mount && !root.running) root.backup() }   // đợi ổ ổn định một chút
    Timer { interval: 600000; running: root.connected; repeat: true; onTriggered: root.maybeAuto() }
    onMountChanged: if (mount) { refreshList(); maybeAuto(); }

    // ---- sao lưu ----
    function backup() {
        if (running || !mount) return;
        error = ""; pct = 0; running = true;
        runner.command = ["islet-backup", "run", mount];
        runner.running = true;
        started(Prefs.backupLabel || label(drive));
    }
    function stop() { if (runner.running) runner.signal(15); }
    Process {
        id: runner
        stdout: SplitParser {
            onRead: l => {
                if (l.startsWith("PROGRESS ")) root.pct = Number(l.slice(9)) || 0;
                else if (l.startsWith("DONE ")) { Prefs.set("backupLast", Date.now()); root.error = ""; }
                else if (l.startsWith("ERROR ")) root.error = l.slice(6);
            }
        }
        onExited: code => {
            root.running = false;
            root.refreshList();
            root.finished(code === 0, code === 0 ? "Backed up to " + (Prefs.backupLabel || "your drive") : (root.error || "Backup stopped"));
        }
    }

    function refreshList() {
        if (!mount) { list = []; return; }
        lister.command = ["islet-backup", "list", mount];
        lister.running = true;
    }
    Process {
        id: lister
        stdout: StdioCollector { onStreamFinished: { try { root.list = JSON.parse(text) || []; } catch (e) { root.list = []; } } }
    }
}
