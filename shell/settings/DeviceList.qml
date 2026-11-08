// Thành phần dùng chung của app Cài đặt.
import QtQuick
import "../theme"
import "../common"

Rectangle {
    id: dlst
    property var nodes: []
    property var current: null
    property string empty: ""
    signal picked(var node)
    width: parent ? parent.width : 300
    height: dcol.implicitHeight + 8
    radius: 18
    color: Theme.fg(0.05)
    Column {
        id: dcol
        y: 4
        width: parent.width
        Text { visible: dlst.nodes.length === 0; leftPadding: 18; topPadding: 12; bottomPadding: 12; text: dlst.empty; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
        Repeater {
            model: dlst.nodes
            Rectangle {
                id: dv
                required property var modelData
                readonly property bool on: dlst.current === modelData
                width: dcol.width
                height: 46
                radius: 14
                color: dvm.containsMouse ? Theme.fg(0.05) : "transparent"
                Rectangle {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: dv.on ? Theme.accent : Theme.fg(0.3)
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: dv.on }
                }
                Text {
                    x: 46; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 60; elide: Text.ElideRight
                    text: dv.modelData.description || dv.modelData.nickname || dv.modelData.name
                    color: Theme.label; font.family: Theme.font; font.pixelSize: 13; font.weight: dv.on ? Font.DemiBold : Font.Normal
                }
                MouseArea { id: dvm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlst.picked(dv.modelData) }
            }
        }
    }
}
