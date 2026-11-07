pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cập nhật hệ thống: kiểm tra định kỳ (checkupdates + AUR, không cần root), báo trên island khi có bản mới,
// cập nhật bằng một nút (Packages, việc "system:upgrade" → islet-pkg upgrade, có thanh tiến trình).
Singleton {
    id: root

    property var list: []            // { name, from, to, aur, islet }
    // tên dễ hiểu cho các gói của Islet (kho [islet])
    readonly property var isletNames: ({ "islet": "Islet", "islet-shell": "Islet desktop", "islet-tools": "Islet tools",
                                         "islet-themes": "Islet look (icons, wallpapers, cursors)", "islet-keyring": "Islet signing key" })
    readonly property int isletCount: list.filter(u => u.islet).length
    property bool checking: false
    property real lastCheck: 0
    property string error: ""
    readonly property int count: list.length
    readonly property bool running: Packages.current?.pkg === "system:upgrade" || Packages.queue.some(j => j.pkg === "system:upgrade")
    property bool needsReboot: false

    signal available(int n)

    // Nhật ký thay đổi của Islet cho bản cập nhật đang chờ: [{ subject, detail, time }], mới nhất trước.
    // islet-changes.json (cạnh kho [islet]) ghi mỗi commit đổi gói nào và phiên bản gói đó sau commit;
    // giữ các commit có phiên bản nằm trong (đang có, bản mới] của một gói Islet đang chờ cập nhật.
    property var changes: []
    function rev(v) { const m = String(v).match(/\.r(\d+)/); return m ? Number(m[1]) : -1; }
    Process {
        id: changesProc
        property int notify: 0
        command: ["islet-pkg", "changes"]
        stdout: StdioCollector {
            onStreamFinished: {
                let all = [];
                try { all = JSON.parse(text).changes || []; } catch (e) {}
                const pend = root.list.filter(u => u.islet);
                root.changes = all.filter(c => pend.some(u => {
                    const r = c.revs?.[u.name];
                    return r !== undefined && r > root.rev(u.from) && r <= root.rev(u.to);
                }));
                if (changesProc.notify > 0) root.available(changesProc.notify);
                changesProc.notify = 0;
            }
        }
    }

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
                    return { name: p[0], from: p[1], to: p[2], aur: p[3] === "aur", islet: /^islet(-|$)/.test(p[0]) };
                }).sort((a, b) => b.islet - a.islet);          // bản cập nhật của chính Islet lên đầu
                root.checking = false;
                root.lastCheck = Date.now();
                // có bản mới của Islet → lấy nhật ký thay đổi trước, rồi mới báo (island hiện được điểm mới)
                const notify = root.count > 0 && root.count !== before ? root.count : 0;
                if (root.isletCount > 0) { changesProc.notify = notify; changesProc.running = true; }
                else { root.changes = []; if (notify) root.available(notify); }
            }
        }
        onExited: code => { if (code !== 0 && code !== 2) root.error = "Couldn't check for updates"; root.checking = false; }
    }

    // sau khi cập nhật xong → kiểm tra lại
    Connections {
        target: Packages
        function onFinished(pkg, op, ok) { if (pkg === "system:upgrade") { root.list = ok ? [] : root.list; recheck.restart(); Sounds.play(ok ? "done" : "error"); } }
        function onRebootNeeded() { root.needsReboot = true; }
    }
    Timer { id: recheck; interval: 3000; onTriggered: root.check() }

    // lần đầu sau khi bật máy 2 phút, rồi cứ 4 giờ một lần
    Timer { interval: 120000; running: true; onTriggered: root.check() }
    Timer { interval: 4 * 3600 * 1000; running: true; repeat: true; onTriggered: root.check() }
}
