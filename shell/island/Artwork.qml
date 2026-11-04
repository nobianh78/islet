import QtQuick
import Quickshell.Widgets
import "../theme"

// Ảnh bìa bài hát, bo góc. Không có ảnh thì hiện nền gradient + nốt nhạc.
ClippingRectangle {
    id: root

    property string source: ""
    property real iconSize: width * 0.46

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#7C6BFF" }
            GradientStop { position: 1; color: "#FF5E8A" }
        }
        Image {
            anchors.centerIn: parent
            width: root.iconSize
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: Qt.resolvedUrl("../assets/icons/music.svg")
        }
    }

    Image {
        id: art
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize: Qt.size(256, 256)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }
}
