// Thành phần dùng chung của app Cài đặt.
import QtQuick
import "../theme"
import "../common"

Rectangle {
    id: pb
    property string label: ""
    property bool primary: false
    signal clicked()
    width: pl.implicitWidth + 28
    height: 32
    radius: 16
    color: primary ? (pm2.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent) : (pm2.containsMouse ? Theme.fg(0.18) : Theme.fg(0.09))
    Behavior on color { ColorAnimation { duration: 130 } }
    scale: pm2.pressed ? 0.94 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
    Text { id: pl; anchors.centerIn: parent; text: pb.label; color: pb.primary ? "#FFFFFF" : Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Bold }
    MouseArea { id: pm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
}
