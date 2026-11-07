// Ba nút cửa sổ của app Islet: 🔴 đóng · 🟡 thu nhỏ · 🟢 phóng to (giống GTK/Firefox trong Islet).
// Rê chuột vào cụm nút thì hiện ký hiệu bên trong.
import QtQuick
import "../theme"

Row {
    id: root
    signal close()
    signal minimize()
    signal maximize()
    spacing: 8
    HoverHandler { id: hov }
    Repeater {
        model: [
            { c: "#FF5F57", icon: "close",  act: 0 },
            { c: "#FEBC2E", icon: "minus",  act: 1 },
            { c: "#28C840", icon: "expand", act: 2 }
        ]
        Rectangle {
            required property var modelData
            width: 13; height: 13; radius: 6.5
            color: modelData.c
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25)
            scale: dm.pressed ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Icon { anchors.centerIn: parent; name: parent.modelData.icon; size: 9; color: "#3A1A10"; opacity: hov.hovered ? 0.85 : 0 }
            MouseArea {
                id: dm
                anchors.fill: parent; anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: [root.close, root.minimize, root.maximize][parent.modelData.act]()
            }
        }
    }
}
