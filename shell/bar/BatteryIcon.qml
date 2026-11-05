import QtQuick
import "../theme"
import "../services"

// Biểu tượng pin vẽ tay, giống thiết kế. Ẩn khi máy không có pin.
Item {
    id: root
    visible: Power.present
    implicitWidth: visible ? 26 : 0
    implicitHeight: 14

    readonly property real level: Math.max(0, Math.min(1, Power.percent / 100))
    readonly property color fill: Power.charging ? Theme.green : level < 0.15 ? Theme.red : Theme.text

    Rectangle {
        width: 22
        height: 12
        anchors.verticalCenter: parent.verticalCenter
        radius: 3.5
        color: "transparent"
        border.color: Theme.text
        border.width: 1.4

        Rectangle {
            x: 2.5
            y: 2.5
            height: parent.height - 5
            width: Math.max(2, (parent.width - 5) * root.level)
            radius: 1.6
            color: root.fill
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
    Rectangle {
        x: 23.5
        anchors.verticalCenter: parent.verticalCenter
        width: 2.2
        height: 4
        radius: 1
        color: Theme.text
    }
}
