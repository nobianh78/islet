pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Lịch sử clipboard (tab Clipboard trên island).
//   · theo dõi bằng `islet-clip watch` (wl-paste --watch), nhận chữ (base64) và ảnh (đường dẫn png)
//   · lưu ~/.local/share/islet/clipboard.json (50 mục; mục ghim không bị đẩy ra)
//   · paste(item): đặt lại vào clipboard rồi gửi Ctrl+V (terminal: Ctrl+Shift+V) vào cửa sổ đang dùng
Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/islet/clipboard.json"
    readonly property int limit: 50

    // { id, kind: "text"|"image", text, path, time (ms), pinned }
    property var items: []
    property int nextId: 1

    function b64decode(s) {
        // Qt.atob trả về chuỗi byte; giải UTF-8 bằng decodeURIComponent(escape(...))
        try { return decodeURIComponent(escape(Qt.atob(s))); } catch (e) { return Qt.atob(s); }
    }

    function add(kind, value) {
        if (kind === "text" && value.trim() === "") return;
        // trùng thì đưa lên đầu, không thêm mới
        const same = items.find(x => x.kind === kind && (kind === "text" ? x.text === value : x.path === value));
        let rest = items.filter(x => x !== same);
        const it = same ? Object.assign({}, same, { time: Date.now() })
            : { id: nextId++, kind: kind, text: kind === "text" ? value : "", path: kind === "image" ? value : "", time: Date.now(), pinned: false };
        const pinned = rest.filter(x => x.pinned), loose = rest.filter(x => !x.pinned);
        items = [it].concat(pinned, loose).slice(0, Math.max(limit, pinned.length + 1));
        save.restart();
    }
    function remove(id) { items = items.filter(x => x.id !== id); save.restart(); }
    function togglePin(id) {
        items = items.map(x => x.id === id ? Object.assign({}, x, { pinned: !x.pinned }) : x);
        save.restart();
    }
    function clear() { items = items.filter(x => x.pinned); save.restart(); }

    // đặt lại vào clipboard; paste = true thì dán luôn vào cửa sổ đang dùng
    function use(item, paste) {
        if (item.kind === "image") Quickshell.execDetached(["islet-clip", "copy-image", item.path]);
        else { copier.text = item.text; copier.running = true; }
        if (paste) pasteLater.restart();
    }
    Process {
        id: copier
        property string text: ""
        command: ["wl-copy", "--"]
        stdinEnabled: true
        onStarted: { write(text); stdinEnabled = false; }
        onExited: stdinEnabled = true
    }
    readonly property var terminals: ["kitty", "alacritty", "foot", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "ghostty",
        "org.gnome.Console", "org.gnome.Terminal", "konsole", "xterm"]
    // đợi island thu lại và cửa sổ cũ nhận bàn phím rồi mới gửi phím dán
    Timer {
        id: pasteLater
        interval: 220
        onTriggered: {
            const cls = Hyprland.activeToplevel?.lastIpcObject?.class ?? "";
            const mods = root.terminals.indexOf(cls) >= 0 ? "CTRL SHIFT" : "CTRL";
            Hyprland.dispatch('hl.dsp.send_shortcut({ mods = "' + mods + '", key = "V" })');
        }
    }

    // ---- theo dõi ----
    Process {
        id: watcher
        running: true
        command: ["islet-clip", "watch"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("T ")) root.add("text", root.b64decode(line.slice(2)));
                else if (line.startsWith("I ")) root.add("image", line.slice(2));
            }
        }
        // wl-paste thoát (vd. compositor khởi động lại) → chạy lại sau chốc lát
        onExited: restartWatch.restart()
    }
    Timer { id: restartWatch; interval: 3000; onTriggered: watcher.running = true }

    // ---- lưu / đọc ----
    Process {
        running: true
        command: ["mkdir", "-p", root.file.substring(0, root.file.lastIndexOf("/"))]
        onExited: store.reload()
    }
    FileView {
        id: store
        path: root.file
        blockLoading: false
        onLoaded: {
            try {
                const d = JSON.parse(text() || "{}");
                if (Array.isArray(d.items)) {
                    root.items = d.items;
                    root.nextId = d.items.reduce((m, x) => Math.max(m, x.id || 0), 0) + 1;
                }
            } catch (e) {}
        }
    }
    Timer {
        id: save
        interval: 400
        onTriggered: store.setText(JSON.stringify({ items: root.items }))
    }
}
