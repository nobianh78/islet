import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"

// Viền sáng quanh cửa sổ đang được điều khiển, hiện khi rê chuột vào ba chấm trên thanh.
// Lớp phủ trong suốt, không nhận chuột.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false

    WlrLayershell.namespace: "islet-frame"
    // Cùng tầng với tab ba chấm nhưng tạo trước, nên nằm dưới tab (không phủ mờ ba chấm).
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {}

    readonly property bool shown: Ui.frameHint && Windows.hasActive
    visible: shown || frame.opacity > 0.01

    // Vị trí cửa sổ theo Hyprland (toạ độ toàn cục → toạ độ màn hình này).
    readonly property var ipc: Windows.active?.lastIpcObject ?? null
    readonly property real wx: (ipc?.at?.[0] ?? 0) - (screen?.x ?? 0)
    readonly property real wy: (ipc?.at?.[1] ?? 0) - (screen?.y ?? 0)
    readonly property real ww: ipc?.size?.[0] ?? 0
    readonly property real wh: ipc?.size?.[1] ?? 0

    onShownChanged: if (shown) Hyprland.refreshToplevels()

    Item {
        id: frame
        x: win.wx - 4
        y: win.wy - 4
        width: win.ww + 8
        height: win.wh + 8
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 1.025
        Behavior on opacity { NumberAnimation { duration: win.shown ? 180 : 260; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.34; epsilon: 0.0005 } }

        // Quầng sáng mềm
        Rectangle {
            id: glowSrc
            anchors.fill: parent
            radius: 22
            color: "transparent"
            border.width: 3
            border.color: Theme.violet
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: glowSrc
            source: glowSrc
            blurEnabled: true
            blurMax: 24
            blur: 0.8
            opacity: 0.9
        }
        // Viền rõ
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 20
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(1, 1, 1, 0.75)
        }
    }
}
