pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// App được ghim trên dock (theo id .desktop), lưu ở ~/.config/islet/dock.json
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/islet"
    readonly property var defaults: ["org.gnome.Nautilus", "firefox", "kitty", "code-oss", "islet-store"]

    property var pins: defaults

    function isPinned(id) { return pins.indexOf(id) >= 0; }
    function pin(id) { pinAt(id, -1); }
    function pinAt(id, index) {
        if (!id || id === "islet-settings") return;      // Cài đặt luôn có sẵn ở cuối dock
        let p = pins.filter(x => x !== id);
        if (index === undefined || index < 0 || index >= p.length) {
            p.push(id);
        } else {
            p.splice(index, 0, id);
        }
        pins = p;
        save.restart();
    }
    // bỏ ghim một app của dock (mọi tên id của nó)
    function unpinApp(app) {
        const ids = [app.pinId, app.key].concat(app.ids ?? []);
        pins = pins.filter(p => ids.indexOf(p) < 0);
        save.restart();
    }
    function unpin(id) {
        pins = pins.filter(p => p !== id);
        save.restart();
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: file.reload()
    }
    FileView {
        id: file
        path: root.dir + "/dock.json"
        blockLoading: false
        onLoaded: {
            try {
                const d = JSON.parse(text() || "{}");
                if (Array.isArray(d.pins)) root.pins = d.pins.filter(x => x !== "islet-settings");
            } catch (e) {}
        }
    }
    Timer {
        id: save
        interval: 300
        onTriggered: file.setText(JSON.stringify({ pins: root.pins }, null, 1))
    }
}
