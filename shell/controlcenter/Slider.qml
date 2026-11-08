import QtQuick
import "../theme"
import "../common"

// Thanh trượt to kiểu iOS: kéo hoặc lăn chuột để chỉnh; dày lên khi đang kéo.
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property real value: 0.5
    property color fill: Theme.label
    property bool available: true
    property var label: null          // hàm v → chữ hiện bên phải (mặc định: phần trăm)

    signal moved(real v)

    implicitHeight: 52
    radius: 22
    color: "transparent"
    opacity: available ? 1 : 0.45

    property real dragValue: value
    readonly property real shown: drag.pressed ? dragValue : value

    Glass { anchors.fill: parent; radius: parent.radius; color: Theme.glassFill }

    Text {
        x: 16; y: 8
        text: root.title
        color: Theme.label
        font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 8
        text: root.label ? root.label(root.shown) : Math.round(root.shown * 100) + "%"
        color: Theme.fg(0.6)
        font.family: Theme.font; font.pixelSize: 11
        font.features: ({ "tnum": 1 })
    }

    // thanh mảnh + núm tròn dài như macOS
    Rectangle {
        id: track
        x: 14
        width: parent.width - 28
        y: parent.height - 18
        height: 6; radius: 3
        color: Theme.fg(0.2)
        Rectangle {
            height: parent.height; radius: parent.radius
            width: thumb.x + thumb.width / 2
            color: root.fill
            opacity: 0.55
        }
        Rectangle {
            id: thumb
            width: 30; height: 20; radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: (track.width - width) * Math.max(0, Math.min(1, root.shown))
            color: "#FFFFFF"
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.12)
            scale: drag.pressed ? 1.08 : 1
            Behavior on scale { SpringAnimation { spring: 5; damping: 0.4 } }
            Behavior on x { enabled: !drag.pressed; SpringAnimation { spring: 5; damping: 0.42 } }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.available
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function at(mx) { return Math.max(0, Math.min(1, (mx - track.x - thumb.width / 2) / (track.width - thumb.width))); }
        onPressed: m => { root.dragValue = at(m.x); root.moved(root.dragValue); }
        onPositionChanged: m => { if (pressed) { root.dragValue = at(m.x); root.moved(root.dragValue); } }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
