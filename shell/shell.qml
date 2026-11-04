import QtQuick
import Quickshell
import Quickshell.Io
import "island"

// Islet shell. Chạy bằng: qs -p shell
ShellRoot {
    Island { id: island }

    // Điều khiển từ terminal hoặc phím tắt:
    //   qs -p shell ipc call island toggle
    //   qs -p shell ipc call island test notif|volume|battery
    IpcHandler {
        target: "island"
        function toggle(): void { island.expanded = !island.expanded; }
        function test(kind: string): void { island.flash(kind, 3000); }
    }
}
