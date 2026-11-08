import QtQuick
import "../theme"
import "../common"

// Ô điều khiển kiểu macOS: viên thuốc (nút tròn + chữ) hoặc chỉ một nút tròn (compact).
// Bật thì nút tròn đổi sang màu của ô; nền kính giữ nguyên.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool available: true
    property bool compact: false
    property color onColor: Theme.violet

    signal toggled()

    implicitHeight: 52
    opacity: available ? 1 : 0.45
    scale: mouse.pressed ? 0.94 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.32 } }

    Glass {
        anchors.fill: parent
        radius: height / 2
        color: root.compact && root.checked ? root.onColor : mouse.containsMouse ? Theme.glassHover : Theme.glassFill
        Behavior on color { ColorAnimation { duration: 220 } }
    }

    // viên thuốc: nút tròn bên trái
    Rectangle {
        visible: !root.compact
        x: 9; anchors.verticalCenter: parent.verticalCenter
        width: 34; height: 34; radius: 17
        color: root.checked ? root.onColor : Theme.fg(0.2)
        Behavior on color { ColorAnimation { duration: 220 } }
        TIcon { anchors.centerIn: parent; name: root.icon; size: 17; color: root.checked ? "#FFFFFF" : Theme.label }
    }
    Column {
        visible: !root.compact
        x: 52; width: parent.width - 52 - 8
        anchors.verticalCenter: parent.verticalCenter
        Text { width: parent.width; text: root.title; color: Theme.label; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
        Text { width: parent.width; visible: text !== ""; text: root.subtitle; color: Theme.fg(0.6); font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight }
    }

    // chỉ nút tròn
    TIcon { visible: root.compact; anchors.centerIn: parent; name: root.icon; size: 20; color: root.checked ? "#FFFFFF" : Theme.label }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
