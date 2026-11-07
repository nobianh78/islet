// Một mục ở cột trái của Cài đặt.
import QtQuick
import "../theme"
import "../services"
import "../common"

Rectangle {
    id: nav
    property var item: ({})
    property bool on: false
    width: parent ? parent.width : 200
    height: 32
    radius: 11
    color: on ? Theme.tint(0.22) : nm.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
    Behavior on color { ColorAnimation { duration: 140 } }
    Rectangle {
        x: 8; anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24; radius: 7
        color: Prefs.iconStyle === "color" ? (nav.item.tint ?? Theme.accent) : nav.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.09)
        Behavior on color { ColorAnimation { duration: 160 } }
        Icon { anchors.centerIn: parent; name: nav.item.icon ?? ""; size: 14 }
    }
    Text {
        x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight
        text: nav.item.label ?? ""
        color: nav.on ? "#FFFFFF" : "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12; font.weight: nav.on ? Font.DemiBold : Font.Normal
    }
    MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.settingsPage = nav.item.id }
}
