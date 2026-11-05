pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tình trạng máy cho Quản lý tác vụ. Chạy scripts/sysmon.py (mỗi giây một dòng JSON)
// chỉ khi cửa sổ đang mở; giữ lịch sử 60 giây cho biểu đồ.
Singleton {
    id: root

    property bool active: false
    readonly property int keep: 60

    property var last: null
    property var cpuHist: []
    property var memHist: []
    property var rxHist: []
    property var txHist: []
    property var diskHist: []

    readonly property real cpu: last?.cpu ?? 0
    readonly property var cores: last?.cores ?? []
    readonly property var mem: last?.mem ?? ({ used: 0, total: 1, swapUsed: 0, swapTotal: 0 })
    readonly property var net: last?.net ?? ({ rx: 0, tx: 0 })
    readonly property var disk: last?.disk ?? ({ used: 0, total: 1, read: 0, write: 0 })
    readonly property var temp: last?.temp ?? null
    readonly property real uptime: last?.uptime ?? 0
    readonly property var procs: last?.procs ?? []      // [pid, ppid, name, cpu, rss, user]

    function push(arr, v) {
        const a = arr.slice(-(keep - 1));
        a.push(v);
        return a;
    }

    // Tổng CPU / RAM của một tiến trình và mọi tiến trình con của nó.
    function treeUsage(pid) {
        const kids = {};
        for (const p of procs) (kids[p[1]] = kids[p[1]] || []).push(p);
        const byPid = {};
        for (const p of procs) byPid[p[0]] = p;
        let cpu = 0, rss = 0, n = 0;
        const stack = [pid];
        while (stack.length) {
            const id = stack.pop();
            const p = byPid[id];
            if (p) { cpu += p[3]; rss += p[4]; n++; }
            for (const c of (kids[id] || [])) stack.push(c[0]);
        }
        return { cpu: cpu, rss: rss, count: n };
    }

    function bytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576) return (b / 1048576).toFixed(b >= 104857600 ? 0 : 1) + " MB";
        if (b >= 1024) return Math.round(b / 1024) + " KB";
        return Math.round(b) + " B";
    }
    function rate(b) { return bytes(b) + "/s"; }
    function duration(sec) {
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function kill(pid, force) {
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]);
    }

    Process {
        id: proc
        running: root.active
        command: ["python3", "-u", Qt.resolvedUrl("../scripts/sysmon.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }
                root.last = d;
                root.cpuHist = root.push(root.cpuHist, d.cpu);
                root.memHist = root.push(root.memHist, d.mem.total > 0 ? d.mem.used / d.mem.total * 100 : 0);
                root.rxHist = root.push(root.rxHist, d.net.rx);
                root.txHist = root.push(root.txHist, d.net.tx);
                root.diskHist = root.push(root.diskHist, d.disk.read + d.disk.write);
            }
        }
    }
}
