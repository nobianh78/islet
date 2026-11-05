import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Lớp tối dần khi máy sắp tự khoá (Idle.dimmed); chạm chuột / bàn phím là sáng lại ngay.
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false
    WlrLayershell.namespace: "islet-dim"
    WlrLayershell.layer: WlrLayer.Overlay
    visible: Idle.dimmed || shade.opacity > 0.01
    mask: Region {}
    Rectangle {
        id: shade
        anchors.fill: parent
        color: "#000000"
        opacity: Idle.dimmed ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: Idle.dimmed ? 1800 : 250; easing.type: Easing.InOutQuad } }
    }
}
