import QtQuick
import "../theme"
import "../services"
import "../common"

// Tab "Bây giờ" (chuyển từ _renderNow): đang phát nhạc thì ảnh bìa + tên bài + tiến trình +
// nút điều khiển; không có nhạc thì đồng hồ lớn.
Item {
    id: root

    implicitHeight: Media.hasPlayer ? player.implicitHeight : idle.implicitHeight
    readonly property color accent: Media.accent ?? "#FFFFFF"

    // ---------------- không có nhạc ----------------
    Column {
        id: idle
        visible: !Media.hasPlayer
        width: parent.width
        topPadding: 8
        bottomPadding: 10
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.time
            color: "#FFFFFF"
            font.family: Theme.font
            font.pixelSize: 46
            font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.dateLong
            color: "#D1D1D6"
            font.family: Theme.font
            font.pixelSize: 13
            bottomPadding: 6
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            color: "#8E8E93"
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // ---------------- đang phát ----------------
    Column {
        id: player
        visible: Media.hasPlayer
        width: parent.width
        spacing: 12

        Row {
            width: parent.width
            spacing: 16

            Artwork {
                id: art
                width: 104
                height: 104
                radius: 18
                source: Media.artUrl
                iconSize: 44
                // ảnh bìa nảy lên mỗi khi đổi bài
                Connections {
                    target: Media
                    function onTitleChanged() { artPop.restart(); }
                }
                NumberAnimation { id: artPop; target: art; property: "scale"; from: 0.85; to: 1; duration: 600; easing.type: Easing.OutBack }
            }

            Column {
                width: parent.width - art.width - 16
                topPadding: 4
                spacing: 2
                Text {
                    width: parent.width
                    text: Media.title
                    color: "#FFFFFF"
                    font.family: Theme.font
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Media.artist
                    color: Qt.rgba(1, 1, 1, 0.62)
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    bottomPadding: 8
                }
            }
        }

        // tiến trình
        Row {
            width: parent.width
            spacing: 10
            Text {
                id: tCur
                anchors.verticalCenter: parent.verticalCenter
                text: Media.fmt(Media.position)
                color: "#8E8E93"
                font.family: Theme.font
                font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - tCur.width - tTot.width - 20
                height: seek.containsMouse || seek.pressed ? 7 : 5
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                Behavior on height { NumberAnimation { duration: 160 } }
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: root.accent
                    width: parent.width * (Media.length > 0 ? Math.min(1, Media.position / Media.length) : 0)
                }
                MouseArea {
                    id: seek
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    enabled: Media.canSeek
                    cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: m => Media.seekTo((m.x - 6) / track.width)
                }
            }
            Text {
                id: tTot
                anchors.verticalCenter: parent.verticalCenter
                text: Media.length > 0 ? Media.fmt(Media.length) : ""
                color: "#8E8E93"
                font.family: Theme.font
                font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }
        }

        // điều khiển
        Item {
            width: parent.width
            height: 50

            Row {
                anchors.centerIn: parent
                spacing: 26
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 38; implicitHeight: 38; iconSize: 22
                    icon: Qt.resolvedUrl("../assets/icons/prev.svg")
                    active: Media.active?.canGoPrevious ?? false
                    onClicked: Media.previous()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 44; implicitHeight: 44; iconSize: 22
                    fill: "#FFFFFF"
                    icon: Qt.resolvedUrl(Media.playing ? "../assets/icons/pause.svg" : "../assets/icons/play.svg")
                    onClicked: Media.toggle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 38; implicitHeight: 38; iconSize: 22
                    icon: Qt.resolvedUrl("../assets/icons/next.svg")
                    active: Media.active?.canGoNext ?? false
                    onClicked: Media.next()
                }
            }
        }
    }
}
