pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cập nhật hệ thống: kiểm tra định kỳ (checkupdates + AUR, không cần root), báo trên island khi có bản mới,
// cập nhật bằng một nút (Packages, việc "system:upgrade" → islet-pkg upgrade, có thanh tiến trình).
Singleton {
    id: root

    property var list: []            // { name, from, to, aur }
    property bool checking: false
    property real lastCheck: 0
    property string error: ""
    readonly property int count: list.length
    readonly property bool running: Packages.current?.pkg === "system:upgrade" || Packages.queue.some(j => j.pkg === "system:upgrade")
    property bool needsReboot: false

    signal available(int n)

    function check() {
        if (checking || running) return;
        checking = true;
        error = "";
        proc.running = true;
    }
    function upgrade() {
        if (running) return;
        Packages.enqueue("system:upgrade", "System update", "upgrade", "", ["--all"]);
    }

    Process {
        id: proc
        command: ["islet-pkg", "updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                const before = root.count;
                root.list = text.split("\n").filter(l => l).map(l => {
                    const p = l.split("\t");
                    return { name: p[0], from: p[1], to: p[2], aur: p[3] === "aur" };
                });
                root.checking = false;
                root.lastCheck = Date.now();
                if (root.count > 0 && root.count !== before) root.available(root.count);
            }
        }
        onExited: code => { if (code !== 0 && code !== 2) root.error = "Couldn't check for updates"; root.checking = false; }
    }

    // sau khi cập nhật xong → kiểm tra lại
    Connections {
        target: Packages
        function onFinished(pkg, op, ok) { if (pkg === "system:upgrade") { root.list = ok ? [] : root.list; recheck.restart(); } }
        function onRebootNeeded() { root.needsReboot = true; }
    }
    Timer { id: recheck; interval: 3000; onTriggered: root.check() }

    // lần đầu sau khi bật máy 2 phút, rồi cứ 4 giờ một lần
    Timer { interval: 120000; running: true; onTriggered: root.check() }
    Timer { interval: 4 * 3600 * 1000; running: true; repeat: true; onTriggered: root.check() }
}
