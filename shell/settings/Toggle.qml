// Thành phần dùng chung của app Cài đặt.
import QtQuick
import "../theme"
import "../common"

Rectangle {
    id: tg
    property bool checked: false
    signal toggled()
    width: 46; height: 28; radius: 14
    color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
    Behavior on color { ColorAnimation { duration: 160 } }
    Rectangle {
        y: 3; x: tg.checked ? tg.width - width - 3 : 3
        width: 22; height: 22; radius: 11
        color: "#FFFFFF"
        Behavior on x { SpringAnimation { spring: 5; damping: 0.36; epsilon: 0.1 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
}
