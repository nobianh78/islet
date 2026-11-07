pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Thùng rác (giống macOS): kéo file thả lên thùng rác trên dock để bỏ vào; bấm thùng rác để mở cửa sổ
// Trash — khôi phục, xoá vĩnh viễn từng mục, hoặc dọn sạch. Dùng chung ~/.local/share/Trash với Files.
// Việc thật do /usr/local/bin/islet-trash làm.
Singleton {
    id: root
    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Trash"
    property int count: 0
    property real bytes: 0
    readonly property bool full: count > 0
    property var items: []
    property bool loading: false

    signal received()                 // vừa có file được thả vào (dock nảy nắp)

    function refresh() { cnt.running = true; if (watchers > 0) lst.running = true; }
    property int watchers: 0          // cửa sổ Trash đang mở → đọc cả danh sách
    function load() { loading = true; lst.running = true; }

    function run(args, done) {
        const p = runner.createObject(root, { command: ["islet-trash"].concat(args) });
        p.exited.connect((code) => { if (done) done(code === 0); refresh(); p.destroy(); });
        p.running = true;
    }
    function put(paths) {
        if (!paths.length) return;
        run(["put"].concat(paths), ok => { if (ok) { Sounds.play("trash"); root.received(); } });
    }
    function restore(ids) { run(["restore"].concat(ids)); }
    function remove(ids) { run(["remove"].concat(ids)); }
    function empty() { run(["empty"], ok => { if (ok) Sounds.play("trash"); }); }

    Component { id: runner; Process {} }

    Process {
        id: cnt
        command: ["islet-trash", "count"]
        stdout: StdioCollector {
            onStreamFinished: { const p = text.trim().split(" "); root.count = parseInt(p[0]) || 0; root.bytes = parseFloat(p[1]) || 0; }
        }
    }
    Process {
        id: lst
        command: ["islet-trash", "list"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.items = JSON.parse(text || "[]"); } catch (e) { root.items = []; } root.loading = false; }
        }
    }

    // theo dõi thay đổi (Files xoá file, dọn rác ở nơi khác…)
    Process {
        id: watch
        running: true
        command: ["sh", "-c", 'mkdir -p "$0/files" "$0/info" && exec gio monitor -d "$0/files"', root.dir]
        stdout: SplitParser { onRead: settle.restart() }
        onExited: rewatch.restart()
    }
    Timer { id: rewatch; interval: 5000; onTriggered: watch.running = true }
    Timer { id: settle; interval: 300; onTriggered: root.refresh() }
    Component.onCompleted: cnt.running = true

    function human(b) {
        if (b < 1024) return Math.round(b) + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let i = -1;
        do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
        return (b < 10 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }
}
