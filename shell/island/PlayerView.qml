import QtQuick
import "../theme"
import "../services"

// Island mở rộng: trình phát nhạc đầy đủ như trong thiết kế.
View {
    id: root
    width: 440
    height: 196

    readonly property real frac: Media.length > 0 ? Media.position / Media.length : 0

    Artwork {
        id: art
        x: 22
        y: 22
        width: 68
        height: 68
        radius: 18
        source: Media.artUrl
        iconSize: 32
        scale: Media.playing ? 1 : 0.9
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.28 } }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 16
        anchors.right: eq.left
        anchors.rightMargin: 14
        anchors.verticalCenter: art.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: Media.title
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Media.artist
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    Equalizer {
        id: eq
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: art.verticalCenter
        height: 22
        playing: Media.playing
    }

    // --- Thanh tiến trình (kéo để tua) ---
    Item {
        id: progress
        x: 22
        y: 108
        width: parent.width - 44
        height: 16

        property bool dragging: seek.pressed
        property real dragFrac: 0
        readonly property real shownFrac: dragging ? dragFrac : root.frac

        Text {
            id: tLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: Media.fmt(progress.shownFrac * Media.length)
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }
        Text {
            id: tRight
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Media.fmt(Media.length)
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }

        Rectangle {
            id: trackBar
            anchors.left: tLeft.right
            anchors.right: tRight.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: progress.dragging || seek.containsMouse ? 8 : 4
            radius: height / 2
            color: Theme.track
            Behavior on height { SpringAnimation { spring: 5; damping: 0.4 } }

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, progress.shownFrac)))
                height: parent.height
                radius: parent.radius
                color: Theme.text
            }

            MouseArea {
                id: seek
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                enabled: Media.canSeek
                preventStealing: true
                cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                function fracAt(mx) { return Math.max(0, Math.min(1, (mx - 8) / trackBar.width)); }
                onPressed: m => progress.dragFrac = fracAt(m.x)
                onPositionChanged: m => { if (pressed) progress.dragFrac = fracAt(m.x); }
                onReleased: Media.seekTo(progress.dragFrac)
            }
        }
    }

    // --- Nút điều khiển ---
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 136
        spacing: 30

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Qt.resolvedUrl("../assets/icons/prev.svg")
            active: Media.active?.canGoPrevious ?? false
            onClicked: Media.previous()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 50
            implicitHeight: 50
            fill: Theme.text
            icon: Qt.resolvedUrl(Media.playing ? "../assets/icons/pause.svg" : "../assets/icons/play.svg")
            onClicked: Media.toggle()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Qt.resolvedUrl("../assets/icons/next.svg")
            active: Media.active?.canGoNext ?? false
            onClicked: Media.next()
        }
    }
}
