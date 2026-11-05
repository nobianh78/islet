pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Giữ thư mục "This PC" của Files luôn đúng: dung lượng các ổ, USB vừa cắm / rút, màu nhấn của icon.
// Việc dựng thư mục do /usr/local/bin/islet-thispc làm; ở đây chỉ gọi lại định kỳ.
Singleton {
    id: root
    function refresh() { if (!proc.running) proc.running = true; }
    Process { id: proc; command: ["islet-thispc"] }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    // đổi màu nhấn → vẽ lại icon ổ đĩa theo màu mới
    Connections { target: Prefs; function onAccentIdChanged() { later.restart(); } }
    Timer { id: later; interval: 800; onTriggered: root.refresh() }
}
