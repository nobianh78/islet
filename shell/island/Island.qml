import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// Dynamic Island của Islet.
//
// Chế độ (ưu tiên từ cao xuống thấp):
//   notif   – thông báo mới (5 giây)
//   battery – vừa cắm sạc (2,6 giây)
//   volume  – vừa đổi âm lượng (1,6 giây)
//   player  – trình phát mở rộng (bấm vào island khi có nhạc)
//   music   – thu gọn, có nhạc
//   idle    – đôi mắt mèo
PanelWindow {
    id: win

    anchors.top: true
    margins.top: 6
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 520
    implicitHeight: 260
    color: "transparent"
    focusable: false

    WlrLayershell.namespace: "islet-island"
    WlrLayershell.layer: WlrLayer.Overlay

    // Chỉ phần khung đen nhận chuột; phần trong suốt xung quanh cho click xuyên qua.
    mask: Region { item: body }

    // ---------------- Trạng thái ----------------
    property string transient: ""
    property bool expanded: false
    readonly property bool hovered: hover.hovered

    readonly property string mode: transient !== "" ? transient
        : (expanded && Media.hasPlayer) ? "player"
        : Media.hasPlayer ? "music"
        : "idle"

    // [rộng, cao, bo góc]
    readonly property var sizes: ({
        idle:    [132, 36, 18],
        music:   [300, 36, 18],
        volume:  [320, 40, 20],
        battery: [320, 40, 20],
        notif:   [420, 84, 34],
        player:  [440, 196, 46]
    })
    readonly property var target: sizes[mode]

    // Phình nhẹ khi trỏ chuột vào dạng thu gọn.
    readonly property bool compact: mode === "idle" || mode === "music"
    readonly property real bumpW: hovered && compact ? 14 : 0
    readonly property real bumpH: hovered && compact ? 3 : 0

    readonly property var priority: ({ "": 0, volume: 1, battery: 2, notif: 3 })

    function flash(kind, ms) {
        if (priority[kind] < priority[transient]) return;
        transient = kind;
        transientTimer.interval = ms;
        transientTimer.restart();
    }

    Timer { id: transientTimer; onTriggered: win.transient = "" }

    // Rời chuột khỏi trình phát mở rộng thì tự thu lại sau 2,5 giây.
    Timer {
        id: collapseTimer
        interval: 2500
        running: win.expanded && !win.hovered
        onTriggered: win.expanded = false
    }

    Connections {
        target: Audio
        function onTouched() { win.flash("volume", 1600); }
    }
    Connections {
        target: Power
        function onPlugged() { win.flash("battery", 2600); }
    }
    Connections {
        target: Notifs
        function onArrived(n) { win.flash("notif", 5000); }
    }

    onModeChanged: Media.wantPosition = (mode === "player")

    // ---------------- Khung island ----------------
    Item {
        id: body

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: win.target[0] + win.bumpW
        height: win.target[1] + win.bumpH

        Behavior on width {
            SpringAnimation { spring: Theme.springW; damping: Theme.dampW; mass: Theme.mass; epsilon: 0.25 }
        }
        Behavior on height {
            SpringAnimation { spring: Theme.springH; damping: Theme.dampH; mass: Theme.mass; epsilon: 0.25 }
        }

        // Bóng đổ mềm phía dưới.
        RectangularShadowFallback {
            anchors.fill: shape
            radius: shape.radius
        }

        Rectangle {
            id: shape
            anchors.fill: parent
            radius: Math.min(height / 2, win.target[2])
            color: Theme.ink
            border.color: Theme.hairline
            border.width: 1
            clip: true

            // Ánh sáng mờ phía dưới khi đang phát nhạc mở rộng.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width * 0.8
                height: parent.height * 0.6
                radius: width / 2
                color: Theme.violet
                opacity: win.mode === "player" && Media.playing ? 0.16 : 0
                Behavior on opacity { NumberAnimation { duration: 600 } }
                layer.enabled: opacity > 0
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 1 }
            }

            // Bấm vào island: mở/thu trình phát, hoặc tắt thông báo.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (win.transient === "notif") {
                        win.transient = "";
                        return;
                    }
                    if (Media.hasPlayer) win.expanded = !win.expanded;
                }
            }

            IdleView     { shown: win.mode === "idle"; hovered: win.hovered }
            CompactMusic { shown: win.mode === "music" }
            PlayerView   { shown: win.mode === "player" }
            VolumeView   { shown: win.mode === "volume" }
            BatteryView  { shown: win.mode === "battery" }
            NotifView    { shown: win.mode === "notif" }
        }

        HoverHandler { id: hover }

        // Nảy nhẹ một cái mỗi khi đổi chế độ.
        transform: Scale {
            id: pop
            origin.x: body.width / 2
            origin.y: 0
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: pop; properties: "xScale,yScale"; to: 1.035; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: pop; properties: "xScale,yScale"; to: 1.0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
    onTransientChanged: if (transient !== "") popAnim.restart()
}
