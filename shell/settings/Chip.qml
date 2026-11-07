// Thành phần dùng chung của app Cài đặt.
import QtQuick
import "../theme"
import "../common"

Rectangle {
    id: ch
    property string label: ""
    property bool on: false
    signal clicked()
    width: cl.implicitWidth + 24
    height: 30
    radius: 15
    color: on ? Theme.accent : cm2.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
    Behavior on color { ColorAnimation { duration: 140 } }
    scale: cm2.pressed ? 0.94 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
    Text { id: cl; anchors.centerIn: parent; text: ch.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: ch.on ? Font.DemiBold : Font.Normal }
    MouseArea { id: cm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
}
