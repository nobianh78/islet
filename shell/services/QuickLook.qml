pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Xem nhanh (Quick Look) — bấm Space trên một file ở màn hình nền, trong Thùng rác hay trong một khung.
// Có GNOME Sushi thì dùng Sushi (ảnh, PDF, video, nhạc, code tô màu). Không có thì dùng ô xem nhanh
// của Islet: ảnh, văn bản / code, và thẻ thông tin cho những thứ khác. Bấm Space lần nữa = đóng.
Singleton {
    id: root

    property bool sushi: false
    Process {
        running: true
        command: ["test", "-f", "/usr/share/dbus-1/services/org.gnome.NautilusPreviewer.service"]
        onExited: code => root.sushi = code === 0
    }

    // ---- ô xem nhanh của Islet ----
    property bool open: false
    property string path: ""
    property var info: ({})
    readonly property string name: info.name ?? (path.split("/").pop() || "")

    function show(p) {
        if (!p) return;
        if (sushi) {
            const uri = p.startsWith("file://") ? p : "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
            Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.gnome.NautilusPreviewer",
                "--object-path", "/org/gnome/NautilusPreviewer", "--method", "org.gnome.NautilusPreviewer2.ShowFile", uri, "", "true", ""]);
            return;
        }
        if (open && path === p) { close(); return; }      // đang xem chính nó → đóng
        path = p;
        info = ({});
        infoProc.command = ["islet-desktop", "info", p];
        infoProc.running = true;
        open = true;
    }
    function close() { open = false; }
    function openInApp() {
        if (!path) return;
        Quickshell.execDetached(["islet-desktop", "open", path]);
        close();
    }

    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: { try { root.info = JSON.parse(text || "{}"); } catch (e) { root.info = ({}); } }
        }
    }

    function human(b) {
        if (b < 1024) return Math.round(b) + " B";
        const u = ["KB", "MB", "GB", "TB"];
        let i = -1;
        do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
        return (b < 10 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }
}
