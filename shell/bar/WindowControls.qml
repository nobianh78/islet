import QtQuick
import "../services"
import "../common"

// Ba chấm trên thanh trên cùng — chỉ dùng khi cửa sổ đang chọn không có tab riêng
// (phóng to, sát mép trên, hoặc bị che), để lúc nào cũng có chỗ bấm.
TrafficLights {
    id: root

    readonly property bool shown: Windows.hasActive && !Ui.activeHasTab

    lit: true
    maximized: Windows.activeMaximized
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.5
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.005 } }

    onHoveredChanged: Ui.frameHint = hovered
    onCloseClicked: Windows.close()
    onMinimizeClicked: Windows.minimize()
    onMaximizeClicked: Windows.toggleMaximize()
}
