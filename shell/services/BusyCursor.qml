pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

// Con trỏ "đang mở app": bấm mở app (Dock, Ứng dụng, Islet Search…) → mũi tên kèm vòng quay tím,
// đến khi cửa sổ mới của app hiện ra (hoặc quá 15 giây, với app không có cửa sổ).
// Cách làm: đổi tạm sang theme Islet-Cursors-Busy (scripts/make-cursors.py), trong đó mũi tên và
// bàn tay là hình "progress"; Hyprland vẽ con trỏ cho mọi app nên ở đâu cũng thấy.
Singleton {
    id: root
    readonly property string normalTheme: "Islet-Cursors"
    readonly property string busyTheme: "Islet-Cursors-Busy"
    property bool busy: false
    property int startCount: 0
    readonly property int count: ToplevelManager.toplevels.values.length

    function apply() {
        Quickshell.execDetached(["hyprctl", "setcursor", busy ? busyTheme : normalTheme, String(Prefs.cursorSize)]);
    }
    function begin() {
        startCount = count;
        guard.restart();
        if (!busy) { busy = true; apply(); }
    }
    function end() {
        guard.stop();
        if (busy) { busy = false; apply(); }
    }
    // có cửa sổ mới → app đã mở
    onCountChanged: if (busy && count > startCount) settle.restart()
    // chờ thêm một nhịp cho cửa sổ vẽ xong khung hình đầu
    Timer { id: settle; interval: 250; onTriggered: root.end() }
    Timer { id: guard; interval: 15000; onTriggered: root.end() }

    Connections {
        target: Ui
        function onAppStarting() { root.begin(); }
    }
}
