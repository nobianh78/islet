import QtQuick
import "../theme"
import "../services"

// Island thu gọn khi có nhạc: ảnh bìa nhỏ bên trái, tên bài ở giữa, sóng nhạc bên phải.
View {
    id: root
    width: 300
    height: 36

    Artwork {
        id: art
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 7
        source: Media.artUrl
        scale: Media.playing ? 1 : 0.88
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.3 } }
    }

    Text {
        anchors.left: art.right
        anchors.leftMargin: 10
        anchors.right: eq.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: Media.title
        color: Theme.textDim
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    Equalizer {
        id: eq
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 14
        barWidth: 3
        spacing: 2.5
        playing: Media.playing
    }
}
