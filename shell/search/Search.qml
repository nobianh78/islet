import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Islet Search (giống Spotlight) — Super+Space.
// Một ô tìm: phép tính · đổi đơn vị · trang Cài đặt · app · file (fd) · chạy lệnh · tìm web.
// ↑/↓ chọn, Enter mở, Esc đóng. Gõ "> lệnh" để chạy thẳng lệnh trong terminal.
PanelWindow {
    id: win

    implicitWidth: 680
    implicitHeight: 560
    anchors.top: true
    margins.top: Math.round((screen?.height ?? 800) * 0.14)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-search"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool open: Ui.searchOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    property string query: ""
    property int sel: 0
    onOpenChanged: if (open) { input.text = ""; query = ""; sel = 0; input.forceActiveFocus(); }
    onQueryChanged: { sel = 0; fileTimer.restart(); }

    HyprlandFocusGrab { windows: [win]; active: win.open; onCleared: Ui.searchOpen = false }

    // ================= nguồn kết quả =================
    // ---- phép tính ----
    function calc(q) {
        let s = q.trim().replace(/^=/, "").replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**");
        if (!/[0-9]/.test(s) || !/[-+*/%()a-z]/i.test(s) && !/\*\*/.test(s)) return null;
        s = s.replace(/\b(sqrt|sin|cos|tan|asin|acos|atan|log10|log2|abs|round|floor|ceil|exp|pow|min|max)\b/gi, m => "Math." + m.toLowerCase())
             .replace(/\bln\b/gi, "Math.log").replace(/\blog\b(?!10|2)/gi, "Math.log10").replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/g, "Math.E");
        // chỉ cho phép số, toán tử và Math.*
        if (!/^[\d\s.+\-*/%()]*$/.test(s.replace(/Math\.[A-Za-z0-9]+/g, ""))) return null;
        try {
            const v = Function('"use strict"; return (' + s + ")")();
            if (typeof v !== "number" || !isFinite(v)) return null;
            const r = Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0) ? v.toExponential(6) : String(+v.toPrecision(12));
            return r === q.trim() ? null : r;
        } catch (e) { return null; }
    }
    // ---- đổi đơn vị ----
    readonly property var units: ({
        // độ dài (m)
        mm: ["len", 0.001], cm: ["len", 0.01], m: ["len", 1], km: ["len", 1000], "in": ["len", 0.0254], inch: ["len", 0.0254],
        ft: ["len", 0.3048], yd: ["len", 0.9144], mi: ["len", 1609.344], mile: ["len", 1609.344], nm: ["len", 1852],
        // khối lượng (kg)
        mg: ["mass", 1e-6], g: ["mass", 0.001], kg: ["mass", 1], t: ["mass", 1000], lb: ["mass", 0.45359237], lbs: ["mass", 0.45359237], oz: ["mass", 0.028349523],
        // dung lượng (byte)
        b: ["data", 1], kb: ["data", 1e3], mb: ["data", 1e6], gb: ["data", 1e9], tb: ["data", 1e12],
        kib: ["data", 1024], mib: ["data", 1048576], gib: ["data", 1073741824], tib: ["data", 1099511627776],
        // thời gian (s)
        ms: ["time", 0.001], s: ["time", 1], sec: ["time", 1], min: ["time", 60], h: ["time", 3600], hr: ["time", 3600], d: ["time", 86400], day: ["time", 86400], wk: ["time", 604800],
        // tốc độ (m/s)
        kmh: ["speed", 1 / 3.6], "km/h": ["speed", 1 / 3.6], mph: ["speed", 0.44704], "m/s": ["speed", 1], kn: ["speed", 0.514444],
        // thể tích (l)
        ml: ["vol", 0.001], l: ["vol", 1], gal: ["vol", 3.785411784], cup: ["vol", 0.2365882365],
        // nhiệt độ (đặc biệt)
        c: ["temp", 0], f: ["temp", 0], k: ["temp", 0]
    })
    function convert(q) {
        const m = q.trim().toLowerCase().replace(/°/g, "").match(/^(-?\d+(?:[.,]\d+)?)\s*([a-z/]+)\s+(?:to|in|->|=|sang)\s+([a-z/]+)$/);
        if (!m) return null;
        const v = parseFloat(m[1].replace(",", ".")), a = units[m[2]], b = units[m[3]];
        if (!a || !b || a[0] !== b[0]) return null;
        let r;
        if (a[0] === "temp") {
            const toC = { c: x => x, f: x => (x - 32) * 5 / 9, k: x => x - 273.15 }[m[2]];
            const fromC = { c: x => x, f: x => x * 9 / 5 + 32, k: x => x + 273.15 }[m[3]];
            r = fromC(toC(v));
        } else r = v * a[1] / b[1];
        return +r.toPrecision(8) + " " + m[3] + "   (" + v + " " + m[2] + ")";
    }
    // ---- trang Cài đặt + lệnh nhanh ----
    readonly property var shortcuts: [
        { k: "wallpaper background hình nền", t: "Wallpaper", s: "Settings", icon: "palette", run: () => Ui.openSettings("wallpaper") },
        { k: "accent color theme icon style màu", t: "Accent color", s: "Settings", icon: "sparkle", run: () => Ui.openSettings("accent") },
        { k: "wifi wi-fi network internet mạng", t: "Wi-Fi", s: "Settings", icon: "wifi", run: () => Ui.openSettings("wifi") },
        { k: "phone android iphone kde connect điện thoại", t: "Phone", s: "Settings", icon: "phone", run: () => Ui.openSettings("phone") },
        { k: "bluetooth headphones pair tai nghe", t: "Bluetooth", s: "Settings", icon: "bluetooth", run: () => Ui.openSettings("bluetooth") },
        { k: "sound volume audio microphone âm thanh", t: "Sound", s: "Settings", icon: "volume", run: () => Ui.openSettings("sound") },
        { k: "display resolution scale brightness monitor màn hình", t: "Displays", s: "Settings", icon: "sun", run: () => Ui.openSettings("display") },
        { k: "account password user lock tài khoản mật khẩu", t: "Account", s: "Settings", icon: "user", run: () => Ui.openSettings("account") },
        { k: "update upgrade cập nhật", t: "Updates", s: "Settings", icon: "download", run: () => Ui.openSettings("updates") },
        { k: "about system info version", t: "About this computer", s: "Settings", icon: "islet", run: () => Ui.openSettings("about") },
        { k: "record screen recording quay màn hình", t: "Record screen", s: "Select an area, Esc for full screen", icon: "record", run: () => Recorder.start(true) },
        { k: "screenshot capture chụp màn hình", t: "Take a screenshot", s: "Select an area and annotate", icon: "image", run: () => Quickshell.execDetached(["islet-shot", "area"]) },
        { k: "timer countdown stopwatch pomodoro đồng hồ", t: "Timer & Pomodoro", s: "Dynamic Island", icon: "timer", run: () => Ui.openIsland("timer") },
        { k: "clipboard history copy", t: "Clipboard history", s: "Dynamic Island", icon: "clipboard", run: () => Ui.openIsland("clipboard") },
        { k: "lock khoá", t: "Lock screen", s: "Power", icon: "lock", run: () => Ui.lock() },
        { k: "task manager process cpu ram", t: "Task Manager", s: "System", icon: "activity", run: () => Ui.toggleTask() },
        { k: "store apps install cửa hàng", t: "Store", s: "Find and install apps", icon: "store", run: () => { Ui.openStore(); } },
        { k: "restart reboot khởi động lại", t: "Restart", s: "Power", icon: "restart", run: () => Ui.togglePower() },
        { k: "shutdown power off tắt máy", t: "Shut down", s: "Power", icon: "power", run: () => Ui.togglePower() }
    ]
    function norm(s) { return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d"); }
    function score(text, q) {
        const t = norm(text), n = norm(q);
        if (!n) return 0;
        if (t.startsWith(n)) return 3;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(n))) return 2;
        if (t.includes(n)) return 1;
        return 0;
    }
    // ---- file (fd) ----
    property var files: []
    Timer { id: fileTimer; interval: 160; onTriggered: { win.files = []; if (win.query.trim().length >= 2 && !win.query.startsWith(">")) { fileProc.running = false; fileProc.running = true; } } }
    Process {
        id: fileProc
        command: ["fd", "-i", "--max-results", "8", "--exclude", ".cache", "--exclude", "node_modules", "--exclude", ".git",
                  "--", win.query.trim(), Quickshell.env("HOME")]
        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME");
                win.files = text.split("\n").filter(x => x).map(p => ({
                    kind: "file", title: p.replace(/\/$/, "").split("/").pop(),
                    sub: p.replace(home, "~").replace(/\/[^/]+\/?$/, "") || "~",
                    icon: p.endsWith("/") ? "folder" : "document", path: p.replace(/\/$/, "")
                }));
            }
        }
    }

    // ---- gộp ----
    readonly property var results: {
        const q = query.trim();
        if (!q) return [];
        const out = [];
        if (q.startsWith(">")) {
            const c = q.slice(1).trim();
            if (c) out.push({ kind: "cmd", title: c, sub: "Run in terminal", icon: "terminal", cmd: c });
            return out;
        }
        const conv = convert(q);
        if (conv) out.push({ kind: "copy", title: conv.split("   ")[0], sub: "Unit conversion · " + conv.split("   ")[1] + " · Enter to copy", icon: "calculator", value: conv.split("   ")[0] });
        const c = conv ? null : calc(q);
        if (c !== null) out.push({ kind: "copy", title: "= " + c, sub: q + " · Enter to copy", icon: "calculator", value: c });
        // app
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
            .map(e => ({ e: e, s: Math.max(score(e.name, q) * 2, score(e.genericName, q), (e.keywords || []).some(k => score(k, q) >= 2) ? 1 : 0) }))
            .filter(x => x.s > 0).sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name)).slice(0, 6);
        for (const a of apps) out.push({ kind: "app", title: a.e.name, sub: a.e.genericName || a.e.comment || "Application", entry: a.e });
        // cài đặt / lệnh nhanh
        for (const sc of shortcuts) {
            const sv = Math.max(score(sc.t, q) * 2, sc.k.split(" ").some(w => score(w, q) >= 2) ? 1 : 0);
            if (sv > 0) out.push({ kind: "action", title: sc.t, sub: sc.s, icon: sc.icon, run: sc.run, s: sv });
        }
        for (const f of files) out.push(f);
        // lệnh terminal (nếu trông giống lệnh) + tìm web
        if (/^[a-z0-9_.-]+(\s|$)/i.test(q) && q.length > 1 && !c && !conv)
            out.push({ kind: "cmd", title: q, sub: "Run in terminal", icon: "terminal", cmd: q });
        out.push({ kind: "web", title: "Search the web for “" + q + "”", sub: "DuckDuckGo", icon: "globe", q: q });
        return out;
    }

    function activate(r) {
        if (!r) return;
        Ui.searchOpen = false;
        if (r.kind === "app") Ui.launchEntry(r.entry);
        else if (r.kind === "action") r.run();
        else if (r.kind === "file") Quickshell.execDetached(["xdg-open", r.path]);
        else if (r.kind === "cmd") Quickshell.execDetached(["kitty", "--hold", "sh", "-c", r.cmd]);
        else if (r.kind === "web") Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(r.q)]);
        else if (r.kind === "copy") { Clipboard.use({ kind: "text", text: r.value }, false); Ui.toast("Copied " + r.value, "", ""); }
    }

    // ================= giao diện =================
    Glass {
        id: panel
        width: parent.width
        height: 64 + (win.results.length ? Math.min(list.contentHeight + 14, parent.height - 64) : 0)
        radius: 26
        color: Theme.surface(0.78)
        clip: true
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.002 } }
        Behavior on height { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.3 } }

        TIcon { x: 22; y: 22; name: "search"; size: 20; opacity: 0.7 }
        TextInput {
            id: input
            x: 56; y: 0
            width: parent.width - 76
            height: 64
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.label
            font.family: Theme.font
            font.pixelSize: 20
            selectionColor: Theme.tint(0.5)
            onTextChanged: win.query = text
            Keys.onEscapePressed: Ui.searchOpen = false
            Keys.onDownPressed: win.sel = Math.min(win.results.length - 1, win.sel + 1)
            Keys.onUpPressed: win.sel = Math.max(0, win.sel - 1)
            Keys.onReturnPressed: win.activate(win.results[win.sel])
            Keys.onEnterPressed: win.activate(win.results[win.sel])
            Keys.onTabPressed: win.sel = (win.sel + 1) % Math.max(1, win.results.length)
        }
        Text {
            visible: input.text === ""
            x: 56; height: 64
            verticalAlignment: Text.AlignVCenter
            text: "Search apps, files, settings — or type 2+2, 10 km to mi, > command"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 16
        }
        Rectangle { y: 63; width: parent.width; height: 1; color: Theme.fg(0.07); visible: win.results.length > 0 }

        ListView {
            id: list
            x: 8; y: 70
            width: parent.width - 16
            height: parent.height - 76
            clip: true
            model: win.results
            currentIndex: win.sel
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            highlightMoveDuration: 0
            highlight: Rectangle { radius: 14; color: Theme.tint(0.22) }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: 52
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.sel = row.index
                    onClicked: win.activate(row.modelData)
                }
                // icon: app → AppIcon, còn lại → ô tròn có glyph
                AppIcon {
                    visible: row.modelData.kind === "app"
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    name: row.modelData.kind === "app" ? (Theme.appKey(row.modelData.entry.id) || Theme.appKey(row.modelData.entry.icon)) : ""
                    source: row.modelData.kind === "app" ? (Quickshell.iconPath(row.modelData.entry.icon, true) || "") : ""
                }
                Rectangle {
                    visible: row.modelData.kind !== "app"
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 10
                    color: row.modelData.kind === "copy" ? Theme.tint(0.3) : Theme.fg(0.08)
                    TIcon { anchors.centerIn: parent; name: row.modelData.icon || "search"; size: 16 }
                }
                Column {
                    x: 56; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - hint.width - 24
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: row.modelData.title
                        color: Theme.label; font.family: row.modelData.kind === "cmd" ? Theme.mono : Theme.font
                        font.pixelSize: row.modelData.kind === "copy" ? 17 : 14
                        font.weight: row.modelData.kind === "copy" ? Font.Bold : Font.Medium
                    }
                    Text { width: parent.width; elide: Text.ElideMiddle; text: row.modelData.sub || ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                }
                Text {
                    id: hint
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.index === win.sel
                    text: "↵"
                    color: Theme.muted; font.pixelSize: 15
                }
            }
        }
    }
}
