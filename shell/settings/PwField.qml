// Thành phần dùng chung của app Cài đặt.
import QtQuick
import "../theme"
import "../common"

Rectangle {
    id: pf
    property string hint: ""
    property alias text: pfIn.text
    signal accepted()
    function focusField() { pfIn.forceActiveFocus(); }
    height: 36; radius: 12
    color: Theme.fg(0.08)
    border.width: 1
    border.color: pfIn.activeFocus ? Theme.tint(0.7) : Theme.fg(0.1)
    TextInput {
        id: pfIn
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        color: Theme.label; font.family: Theme.font; font.pixelSize: 13
        Keys.onReturnPressed: pf.accepted()
    }
    Text {
        visible: pfIn.text === ""
        anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
        text: pf.hint; color: Theme.faint; font.family: Theme.font; font.pixelSize: 12
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: pfIn.forceActiveFocus() }
}
