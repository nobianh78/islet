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

        // ---- lời bài hát: cuộn mượt, câu đang hát ở giữa (tô karaoke) ----
        Item {
            id: lyr
            visible: Prefs.islandLyrics && Lyrics.status !== "off" && Lyrics.status !== "idle"
            width: parent.width
            height: Lyrics.status === "ok" ? 74 : 22
            HoverHandler { id: lyrHover }
            Text {
                visible: Lyrics.status !== "ok"
                anchors.verticalCenter: parent.verticalCenter
                text: Lyrics.status === "loading" ? "Finding lyrics…" : Lyrics.status === "error" ? "Lyrics unavailable offline" : "No lyrics for this song"
                color: Qt.rgba(1, 1, 1, 0.4); font.family: Theme.font; font.pixelSize: 12; font.italic: true
            }
            ListView {
                id: lyrList
                visible: Lyrics.status === "ok"
                anchors.fill: parent
                clip: true
                interactive: false
                model: Lyrics.status === "ok" ? Lyrics.lines : []
                // dòng cao cố định → tự đặt vị trí cuộn: câu đang hát luôn ở giữa, cuộn mượt khi đổi câu
                readonly property real rowH: 24
                contentY: Math.max(0, Lyrics.index) * rowH - (height / 2 - rowH / 2) + originY
                Behavior on contentY { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                topMargin: height
                bottomMargin: height
                delegate: Item {
                    id: ld
                    required property var modelData
                    required property int index
                    readonly property bool cur: index === Lyrics.index
                    width: lyrList.width
                    height: lyrList.rowH
                    Text {
                        id: txt
                        visible: !ld.cur
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: ld.modelData[1] || "♪"
                        elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, Math.abs(ld.index - Lyrics.index) === 1 ? 0.42 : 0.22)
                        font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    LyricLine {
                        id: curLine
                        visible: ld.cur
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        text: ld.modelData[1] || "♪"
                        key: "now#" + ld.index
                        progress: ld.cur ? Lyrics.progress : 0
                        pixelSize: 16
                        weight: Font.ExtraBold
                        dim: Qt.rgba(1, 1, 1, 0.45)
                        color: "#FFFFFF"
                    }
                }
            }
            // chỉnh tay khi lời lệch / sai (hiện khi rê chuột vào lời)
            Row {
                visible: Lyrics.status === "ok"
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 4
                opacity: lyrHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                LyrBtn { label: "−0.5s"; tip: "Lyrics later"; onClicked: Lyrics.nudge(-0.5) }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Lyrics.offset > 0 ? "+" : "") + Lyrics.offset.toFixed(1) + "s"
                    color: Qt.rgba(1, 1, 1, 0.55); font.family: Theme.font; font.pixelSize: 10; font.features: ({ "tnum": 1 })
                }
                LyrBtn { label: "+0.5s"; tip: "Lyrics earlier"; onClicked: Lyrics.nudge(0.5) }
                LyrBtn { label: "Wrong lyrics"; onClicked: Lyrics.markWrong() }
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

    component LyrBtn: Rectangle {
        id: lb
        property string label: ""
        property string tip: ""
        signal clicked()
        width: lbt.implicitWidth + 14
        height: 20
        radius: 10
        color: lbm.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.1)
        Text { id: lbt; anchors.centerIn: parent; text: lb.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
        MouseArea { id: lbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lb.clicked() }
    }
}
