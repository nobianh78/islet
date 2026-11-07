import QtQuick
import "../theme"
import "../common"

// Thanh trượt to kiểu iOS: kéo hoặc lăn chuột để chỉnh; dày lên khi đang kéo.
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property real value: 0.5
    property color fill: Theme.text
    property bool available: true
    property var label: null          // hàm v → chữ hiện bên phải (mặc định: phần trăm)

    signal moved(real v)

    implicitHeight: 64
    radius: 18
    color: Qt.rgba(1, 1, 1, 0.10)
    opacity: available ? 1 : 0.45

    property real dragValue: value
    readonly property real shown: drag.pressed ? dragValue : value

    Text {
        x: 14
        y: 10
        text: root.title
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 12
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 10
        text: root.label ? root.label(root.shown) : Math.round(root.shown * 100) + "%"
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 12
        font.features: ({ "tnum": 1 })
    }

    Rectangle {
        id: track
        x: 14
        width: parent.width - 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: drag.pressed ? 10 : 12
        height: drag.pressed ? 12 : 8
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.2)
        Behavior on height { SpringAnimation { spring: 5; damping: 0.4 } }
        Behavior on anchors.bottomMargin { SpringAnimation { spring: 5; damping: 0.4 } }

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.shown)))
            color: root.fill
            Behavior on width { enabled: !drag.pressed; SpringAnimation { spring: 5; damping: 0.42 } }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.available
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function at(mx) { return Math.max(0, Math.min(1, (mx - track.x) / track.width)); }
        onPressed: m => { root.dragValue = at(m.x); root.moved(root.dragValue); }
        onPositionChanged: m => { if (pressed) { root.dragValue = at(m.x); root.moved(root.dragValue); } }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
