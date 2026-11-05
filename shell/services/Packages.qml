pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cài / gỡ / tìm gói cho Cửa hàng Islet (qua /usr/local/bin/islet-pkg và sudo).
// Mỗi lúc chạy một việc; các việc khác xếp hàng. Mật khẩu (nếu cần) giữ trong bộ nhớ tới khi tắt shell.
Singleton {
    id: root

    property var installed: ({})          // tên gói → true
    property var sizes: ({})              // tên gói → { dl, inst }
    property var desktops: ({})           // tên gói → [id .desktop của gói]
    property var appIcons: ({})           // tên gói → icon appstream (app chưa cài, dùng cho kết quả tìm)

    property var results: []              // kết quả tìm: { repo, pkg, ver, installed, desc }
    property bool searching: false
    property string query: ""

    property var queue: []                // { pkg, name, op: "install"|"remove", icon }
    property var current: null            // việc đang chạy
    property int pct: 0
    property string stepText: ""
    property var lastError: ({})          // tên gói → lỗi gần nhất

    // quyền quản trị
    property bool needPassword: false     // sudo cần mật khẩu (máy đã cài); bản live thì không
    property string password: ""
    property bool askPassword: false      // cửa hàng hiện hộp nhập mật khẩu
    signal passwordRejected()

    signal finished(string pkg, string op, bool ok)

    // "2733.18 KiB" → "2.7 MB"
    function human(t) {
        const m = (t || "").match(/([\d.]+)\s*(B|KiB|MiB|GiB)/);
        if (!m) return t;
        const b = parseFloat(m[1]) * ({ B: 1, KiB: 1024, MiB: 1048576, GiB: 1073741824 })[m[2]];
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576) return (b / 1048576).toFixed(b >= 104857600 ? 0 : 1) + " MB";
        return Math.max(1, Math.round(b / 1024)) + " KB";
    }

    function isInstalled(p) { return installed[p.replace(/^aur\//, "")] === true; }
    function busy(p) { return current?.pkg === p || queue.some(j => j.pkg === p); }
    function jobOf(p) { return current?.pkg === p ? current : queue.find(j => j.pkg === p) ?? null; }

    property var watch: []                // gói cần biết id .desktop (danh sách chọn sẵn)
    function refresh() { listProc.running = true; }
    function fetchSizes(pkgs) { sizeProc.command = ["islet-pkg", "sizes"].concat(pkgs); sizeProc.running = true; }

    function search(q) {
        query = q;
        if (!q.trim()) { results = []; return; }
        searchDelay.restart();
    }
    Timer { id: searchDelay; interval: 280; onTriggered: { root.searching = true; searchProc.command = ["islet-pkg", "search", root.query.trim()]; searchProc.running = true; } }

    // pkg: khoá của app (vd. "vlc" hoặc "stack:web"); pkgs: các gói thật cần cài (bộ lập trình có nhiều gói)
    function enqueue(pkg, name, op, icon, pkgs) {
        if (busy(pkg)) return;
        const e = Object.assign({}, lastError); delete e[pkg]; lastError = e;
        queue = queue.concat([{ pkg: pkg, name: name, op: op, icon: icon || "", pkgs: pkgs && pkgs.length ? pkgs : [pkg] }]);
        Ui.toast((op === "install" ? "Installing " : "Removing ") + name + "…", icon || "", "store");
        pump();
    }
    function submitPassword(pw) {
        password = pw;
        askPassword = false;
        pump();
    }
    function cancelPassword() {
        askPassword = false;
        queue = [];
    }

    function pump() {
        if (current || queue.length === 0) return;
        if (needPassword && password === "") { askPassword = true; return; }
        current = queue[0];
        queue = queue.slice(1);
        pct = 0;
        stepText = "Starting…";
        job.command = (needPassword ? ["sudo", "-S", "-p", "", "islet-pkg", current.op]
                                    : ["sudo", "-n", "islet-pkg", current.op]).concat(current.pkgs);
        job.running = true;
    }

    Component.onCompleted: { refresh(); probe.running = true; iconProc.running = true; }

    Process {
        id: iconProc
        command: ["islet-pkg", "appicons"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.split("\n")) {
                    const t = l.indexOf("\t");
                    if (t > 0 && !m[l.slice(0, t)]) m[l.slice(0, t)] = "file://" + l.slice(t + 1);
                }
                root.appIcons = m;
            }
        }
    }

    // sudo có cần mật khẩu không?
    Process {
        id: probe
        command: ["sudo", "-n", "true"]
        onExited: code => root.needPassword = code !== 0
    }

    Process {
        id: listProc
        command: ["islet-pkg", "installed"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const n of text.split("\n")) if (n) m[n] = true;
                root.installed = m;
                // id .desktop của các app trong danh sách chọn sẵn đã cài
                const want = root.watch.filter(p => m[p]);
                if (want.length) { deskProc.command = ["islet-pkg", "desktops"].concat(want); deskProc.running = true; }
            }
        }
    }

    Process {
        id: deskProc
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.split("\n")) {
                    const p = l.split("\t");
                    if (p.length >= 2) (m[p[0]] = m[p[0]] || []).push(p[1]);
                }
                root.desktops = m;
            }
        }
    }

    Process {
        id: sizeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const m = Object.assign({}, root.sizes);
                for (const l of text.split("\n")) {
                    const p = l.split("\t");
                    if (p.length >= 3) m[p[0]] = { dl: root.human(p[1]), inst: root.human(p[2]) };
                }
                root.sizes = m;
            }
        }
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const q = root.query.trim().toLowerCase();
                const out = [];
                for (const l of text.split("\n")) {
                    const p = l.split("\t");
                    if (p.length >= 5)
                        out.push({ repo: p[0], pkg: p[1], ver: p[2], installed: p[3] === "1", desc: p[4] });
                }
                // tên trùng khớp lên đầu
                out.sort((a, b) => (b.pkg === q) - (a.pkg === q) || (b.pkg.startsWith(q)) - (a.pkg.startsWith(q)));
                root.results = out;
                root.searching = false;
            }
        }
    }

    Process {
        id: job
        stdinEnabled: true
        onStarted: if (root.needPassword) write(root.password + "\n")
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("PROGRESS ")) {
                    const sp = line.indexOf(" ", 9);
                    root.pct = parseInt(line.slice(9, sp));
                    root.stepText = line.slice(sp + 1);
                } else if (line.startsWith("ERROR ")) {
                    const e = Object.assign({}, root.lastError); e[root.current.pkg] = line.slice(6); root.lastError = e;
                }
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (/incorrect password|Sorry, try again|no password was provided/i.test(line)) {
                    root.password = "";
                    const e = Object.assign({}, root.lastError); e[root.current.pkg] = "Wrong password"; root.lastError = e;
                    root.passwordRejected();
                }
            }
        }
        onExited: code => {
            const c = root.current;
            const ok = code === 0;
            if (!ok && !root.lastError[c.pkg]) {
                const e = Object.assign({}, root.lastError); e[c.pkg] = "Failed (code " + code + ")"; root.lastError = e;
            }
            Ui.toast(ok ? (c.op === "install" ? "Installed " : "Removed ") + c.name
                        : (c.op === "install" ? "Install " : "Remove ") + c.name + " failed", c.icon, ok ? "store" : "error");
            root.current = null;
            root.finished(c.pkg, c.op, ok);
            root.refresh();
            root.pump();
        }
    }
}
