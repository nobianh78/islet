import QtQuick
import "../theme"
import "../common"

// Ô bật/tắt (Wi-Fi, Bluetooth…). Bật thì nền màu, tắt thì kính mờ.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool available: true
    property color onColor: Theme.teal

    signal toggled()

    implicitHeight: 64
    radius: 18
    color: checked ? onColor : Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.18 : 0.12)
    opacity: available ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 220 } }

    scale: mouse.pressed ? 0.94 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.32 } }

    readonly property color fg: checked ? "#04201C" : Theme.text

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Icon { name: root.icon; size: 18; color: root.fg }
        Column {
            width: parent.width
            Text {
                width: parent.width
                text: root.title
                color: root.fg
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.subtitle
                color: root.checked ? Qt.rgba(0.016, 0.125, 0.11, 0.7) : Theme.textDim
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
