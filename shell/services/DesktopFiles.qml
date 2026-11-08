pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// File, thư mục và lối tắt nằm trên màn hình nền (thư mục ~/Desktop) — việc thật do islet-desktop làm.
//   items  : [{ name, path, dir, size, mtime, kind, icon, image, app, count }]
//   kind   : folder image video audio document archive code app other  (để gom nhóm tự động)
Singleton {
    id: root

    property var items: []
    property string dir: ""
    property bool loaded: false

    readonly property var kindLabels: ({ folder: "Folders", image: "Images", video: "Videos", audio: "Music",
                                         document: "Documents", archive: "Archives", code: "Code", app: "Apps", other: "Other" })
    readonly property var kindOrder: ["folder", "image", "document", "video", "audio", "code", "archive", "app", "other"]

    function refresh() { if (!lst.running) lst.running = true; }
    Component.onCompleted: { where.running = true; refresh(); }

    Process {
        id: where
        command: ["islet-desktop", "dir"]
        stdout: StdioCollector { onStreamFinished: root.dir = text.trim() }
    }
    Process {
        id: lst
        command: ["islet-desktop", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.items = JSON.parse(text || "[]"); } catch (e) { root.items = []; }
                root.loaded = true;
            }
        }
    }

    Component {
        id: runner
        Process {
            id: rp
            signal done(int code, string out)
            property string got: ""
            stdout: StdioCollector { onStreamFinished: rp.got = text }
            onExited: code => rp.done(code, rp.got.trim())
        }
    }
    function run(args, cb) {
        const p = runner.createObject(root, { command: ["islet-desktop"].concat(args) });
        p.done.connect((code, out) => { if (cb) cb(code === 0, out); root.refresh(); p.destroy(); });
        p.running = true;
    }

    function open(path) { Quickshell.execDetached(["islet-desktop", "open", path]); }
    function newFolder(done) { run(["folder"], done); }
    function group(name, paths, done) { if (paths.length) run(["group", name].concat(paths), done); }
    function drop(paths) { if (paths.length) run(["drop"].concat(paths)); }
    function rename(path, name) { if (name) run(["rename", path, name]); }
    function trash(paths) { if (paths.length) run(["trash"].concat(paths)); }

    // theo dõi thay đổi (Files tạo / xoá file, tải về màn hình nền…)
    Process {
        id: watch
        running: root.dir !== ""
        command: ["sh", "-c", 'mkdir -p "$0" && exec gio monitor -d "$0"', root.dir]
        stdout: SplitParser { onRead: settle.restart() }
        onExited: rewatch.restart()
    }
    Timer { id: rewatch; interval: 5000; onTriggered: if (root.dir !== "") watch.running = true }
    Timer { id: settle; interval: 300; onTriggered: root.refresh() }

    function human(b) {
        if (b < 1024) return Math.round(b) + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let i = -1;
        do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
        return (b < 10 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }
}
