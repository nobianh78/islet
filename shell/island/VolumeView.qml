import QtQuick
import "../theme"
import "../services"

// Hiện thoáng qua khi đổi âm lượng.
View {
    id: root
    width: 320
    height: 40

    Image {
        id: icon
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        sourceSize: Qt.size(36, 36)
        source: Qt.resolvedUrl(Audio.muted || Audio.volume <= 0.001
                               ? "../assets/icons/volume-mute.svg" : "../assets/icons/volume.svg")
    }

    Rectangle {
        id: bar
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: pct.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.track

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * (Audio.muted ? 0 : Math.min(1, Audio.volume))
            Behavior on width { SpringAnimation { spring: 5; damping: 0.42 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.violet }
                GradientStop { position: 1; color: Theme.pink }
            }
        }
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: Audio.muted ? "Tắt" : Math.round(Audio.volume * 100) + "%"
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }
}
