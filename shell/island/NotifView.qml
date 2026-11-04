import QtQuick
import Quickshell.Widgets
import "../theme"
import "../services"

// Thông báo mới: icon ứng dụng, tên app, tiêu đề và một dòng nội dung.
View {
    id: root
    width: 420
    height: 84

    readonly property var n: Notifs.latest
    readonly property string iconSrc: Notifs.iconFor(n)

    ClippingRectangle {
        id: icon
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.10)

        Image {
            id: img
            anchors.fill: parent
            source: root.iconSrc
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(96, 96)
            visible: status === Image.Ready
        }
        Image {
            anchors.centerIn: parent
            visible: !img.visible
            width: 24
            height: 24
            sourceSize: Qt.size(48, 48)
            source: Qt.resolvedUrl("../assets/icons/bell.svg")
        }
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.n?.appName ?? ""
            visible: text !== ""
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.n?.summary ?? ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: (root.n?.body ?? "").replace(/\n/g, " ")
            visible: text !== ""
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }
}
