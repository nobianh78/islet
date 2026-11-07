// Ô nhập chữ một dòng (có gợi ý khi trống).
import QtQuick
import "../theme"

Rectangle {
    id: f
    property string hint: ""
    property alias text: inp.text
    signal accepted()
    height: 34; radius: 11
    color: Qt.rgba(1, 1, 1, 0.07)
    border.width: 1
    border.color: inp.activeFocus ? Theme.tint(0.6) : Qt.rgba(1, 1, 1, 0.06)
    TextInput { id: inp; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; clip: true; Keys.onReturnPressed: f.accepted() }
    Text { visible: inp.text === ""; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: f.hint; color: "#636366"; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 20 }
}
