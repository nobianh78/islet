import QtQuick
import "../theme"
import "../common"

// Khung chung cho bảng nhanh trong Control Center: nút quay lại + tiêu đề + công tắc bên phải.
Column {
    id: root
    property string title: ""
    property bool on: true
    property bool showSwitch: true
    default property alias body: bodyCol.data
    signal back()
    signal switched()

    width: parent ? parent.width : 230
    spacing: 8

    Item {
        width: parent.width; height: 34
        Glass {
            width: 34; height: 34; radius: 17
            color: bm.containsMouse ? Theme.glassHover : Theme.glassFill
            Text { anchors.centerIn: parent; text: "‹"; color: Theme.label; font.pixelSize: 22; font.weight: Font.DemiBold }
            MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
        }
        Text { x: 44; anchors.verticalCenter: parent.verticalCenter; text: root.title; color: Theme.label; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.Bold }
        Rectangle {
            visible: root.showSwitch
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 26; radius: 13
            color: root.on ? Theme.accent : Theme.fg(0.2)
            Behavior on color { ColorAnimation { duration: 180 } }
            Rectangle {
                y: 3; width: 20; height: 20; radius: 10; color: "#FFFFFF"
                x: root.on ? 21 : 3
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.switched() }
        }
    }
    Column { id: bodyCol; width: parent.width; spacing: 6 }
}
