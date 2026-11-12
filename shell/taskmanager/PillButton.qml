import QtQuick
import "../theme"

// Nút viên thuốc nhỏ dùng trong Quản lý tác vụ.
Rectangle {
    id: root
    property string label: ""
    property bool danger: false
    property bool armed: false
    signal clicked()

    width: t.implicitWidth + 22
    height: 28
    radius: 14
    color: armed ? "#FF5F57"
        : m.containsMouse ? (danger ? Qt.rgba(1, 0.37, 0.34, 0.85) : Theme.fg(0.18))
        : Theme.fg(0.08)
    Behavior on color { ColorAnimation { duration: 140 } }
    scale: m.pressed ? 0.92 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }

    Text {
        id: t
        anchors.centerIn: parent
        text: root.label
        color: root.armed || (danger && m.containsMouse) ? "#FFFFFF" : Theme.label
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
