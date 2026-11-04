import QtQuick

// Nút tròn có icon, nhún xuống khi bấm.
Item {
    id: root

    property string icon: ""
    property real iconSize: 22
    property color fill: "transparent"
    property color hoverFill: Qt.rgba(1, 1, 1, 0.10)
    property bool active: true

    signal clicked()

    implicitWidth: 44
    implicitHeight: 44
    opacity: active ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.containsMouse && root.fill.a === 0 ? root.hoverFill : root.fill
        scale: mouse.pressed ? 0.86 : mouse.containsMouse ? 1.06 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.32 } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Image {
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            source: root.icon
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
