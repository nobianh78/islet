import QtQuick
import "../theme"
import "../services"
import "../common"

// Island thu gọn (chuyển từ _buildCompact / _renderCompact):
//   idle  : [THỨ TƯ / 4 tháng 11 ……… 20:45]
//   media : [ảnh bìa  Tên bài · Ca sĩ ……… sóng nhạc]
Item {
    id: root

    property string mode: "idle"        // idle | media
    property bool hovered: false

    readonly property color accent: Media.accent ?? "#30D158"

    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // --- idle: cột ngày ---
        Column {
            visible: root.mode === "idle"
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: Time.weekdayUpper
                color: "#8E8E93"
                font.family: Theme.font
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.letterSpacing: 0.4
            }
            Row {
                spacing: 6
                Text {
                    text: Time.dayMonth
                    color: "#E5E5EA"
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                // số việc còn lại hôm nay
                Text {
                    readonly property int n: Calendar.pending(Calendar.key(Time.now))
                    visible: n > 0
                    text: "• " + n + (n === 1 ? " task" : " tasks")
                    color: Theme.violet
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }

        // --- media: ảnh bìa ---
        Artwork {
            visible: root.mode === "media" && Media.artUrl !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 7
            source: Media.artUrl
            iconSize: 13
        }
    }

    // --- media: tên bài · ca sĩ (trượt khi đổi bài) ---
    SlideText {
        visible: root.mode === "media"
        anchors.left: left.right
        anchors.leftMargin: 8
        anchors.right: right.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: Media.artist ? Media.title + " · " + Media.artist : Media.title
        color: "#F2F2F7"
        pixelSize: 13
        weight: Font.DemiBold
    }

    Item {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: (root.mode === "idle" ? clock.implicitWidth + 4 : eq.width) + (agentPill.visible ? agentPill.width + 8 : 0)
        height: parent.height

        // agent lập trình đang chạy: icon agent + vòng quay (đang làm) / chấm cam nhấp nháy (cần bạn)
        Item {
            id: agentPill
            readonly property var s: Agents.sessions.find(x => x.state === "attention") ?? Agents.sessions.find(x => x.state === "working") ?? null
            visible: s !== null
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            Rounded {
                anchors.centerIn: parent
                width: 16; height: 16
                radius: 5
                Image { anchors.fill: parent; source: agentPill.s ? Agents.iconOf(agentPill.s.agent) : ""; sourceSize: Qt.size(32, 32) }
            }
            Canvas {
                id: spin
                anchors.fill: parent
                visible: agentPill.s?.state === "working"
                property real a: 0
                NumberAnimation on a { from: 0; to: Math.PI * 2; duration: 1000; loops: Animation.Infinite; running: spin.visible }
                onAChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset();
                    c.lineWidth = 2; c.lineCap = "round"; c.strokeStyle = Theme.accent;
                    c.beginPath(); c.arc(11, 11, 10, a, a + Math.PI); c.stroke();
                }
            }
            Rectangle {
                visible: agentPill.s?.state === "attention"
                anchors.right: parent.right; anchors.top: parent.top
                width: 8; height: 8; radius: 4
                color: "#FFB547"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: parent.visible
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
        }

        RollingClock {
            id: clock
            visible: root.mode === "idle"
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: Time.time
        }

        EqBars {
            id: eq
            visible: root.mode === "media"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 16
            color: root.accent
            playing: Media.playing
        }
    }
}
