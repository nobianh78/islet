pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Gõ tiếng Việt: fcitx5 + Bamboo. Ctrl+Space (hoặc bấm VI/EN trên thanh trên) để chuyển Việt ⇄ Anh.
// Kiểu gõ (Telex / VNI / VIQR…) ghi vào ~/.config/fcitx5/conf/bamboo.conf rồi bảo fcitx5 nạp lại.
Singleton {
    id: root

    property bool running: false
    property bool vietnamese: false        // fcitx5-remote: 2 = đang bật bộ gõ (Bamboo)
    readonly property var methods: ["Telex", "VNI", "VIQR", "Telex 2", "Telex W", "Microsoft layout"]
    readonly property string confDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/fcitx5"

    function toggle() { Quickshell.execDetached(["fcitx5-remote", "-t"]); poll.restart(); }
    function setMethod(m) {
        Prefs.set("imeMethod", m);
        writer.command = ["sh", "-c", 'mkdir -p "$0/conf"; f="$0/conf/bamboo.conf"; touch "$f"; ' +
            'if grep -q "^InputMethod=" "$f"; then sed -i "s/^InputMethod=.*/InputMethod=$1/" "$f"; else echo "InputMethod=$1" >> "$f"; fi; ' +
            'fcitx5-remote -r 2>/dev/null; true', confDir, m];
        writer.running = true;
    }
    function setEnabled(on) {
        Prefs.set("imeEnabled", on);
        if (on) Quickshell.execDetached(["sh", "-c", "pgrep -x fcitx5 >/dev/null || fcitx5 -d --replace"]);
        else Quickshell.execDetached(["sh", "-c", "fcitx5-remote -e 2>/dev/null; pkill -x fcitx5; true"]);
        poll.restart();
    }
    Process { id: writer }

    // trạng thái: 0 = không chạy · 1 = tắt (EN) · 2 = bật (VI)
    Process {
        id: state
        command: ["fcitx5-remote"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                root.running = v === 1 || v === 2;
                root.vietnamese = v === 2;
            }
        }
        onExited: code => { if (code !== 0) { root.running = false; root.vietnamese = false; } }
    }
    Timer { id: poll; interval: 800; running: Prefs.imeEnabled; repeat: true; triggeredOnStart: true; onTriggered: if (!state.running) state.running = true }
}
