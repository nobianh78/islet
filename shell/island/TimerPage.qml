import QtQuick
import "../theme"
import "../services"
import "../common"

// Tab Timer: đếm ngược nhanh · Pomodoro · bấm giờ. Đang chạy thì hiện vòng tiến trình lớn + nút điều khiển.
Item {
    id: root
    implicitHeight: Chrono.active ? 150 : idle.implicitHeight

    // ---------- chưa chạy: chọn ----------
    Column {
        id: idle
        visible: !Chrono.active
        width: parent.width
        spacing: 12
        Text { text: "Countdown"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        Row {
            spacing: 8
            Repeater {
                model: [1, 3, 5, 10, 15, 30, 45, 60]
                Rectangle {
                    required property int modelData
                    width: 54; height: 40; radius: 14
                    color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                    scale: pm.pressed ? 0.92 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35 } }
                    Text { anchors.centerIn: parent; text: parent.modelData < 60 ? parent.modelData + "m" : "1h"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Chrono.countdown(parent.modelData) }
                }
            }
        }
        Row {
            spacing: 10
            Big { icon: "timer"; title: "Pomodoro"; sub: "25 min focus · 5 min break"; onClicked: Chrono.pomodoro() }
            Big { icon: "activity"; title: "Stopwatch"; sub: "Count up from zero"; onClicked: Chrono.stopwatch() }
        }
        Row {
            spacing: 10
            Big { icon: "moon"; title: Ui.focusMode ? "Focus is on" : "Focus mode"; sub: Ui.focusMode ? "Tap to turn off" : "No banners, desktop hidden, rest dimmed"; onClicked: Ui.focusMode = !Ui.focusMode }
        }
    }

    // ---------- đang chạy ----------
    Item {
        visible: Chrono.active
        width: parent.width
        height: 150

        Canvas {
            id: ring
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 128; height: 128
            property real p: Chrono.mode === "stopwatch" ? (Chrono.elapsed % 60000) / 60000 : Chrono.progress
            onPChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset();
                c.lineWidth = 8; c.lineCap = "round";
                c.strokeStyle = Qt.rgba(1, 1, 1, 0.1);
                c.beginPath(); c.arc(64, 64, 56, 0, Math.PI * 2); c.stroke();
                c.strokeStyle = Chrono.phase.indexOf("reak") >= 0 ? "#34C77B" : Theme.accent;
                c.beginPath(); c.arc(64, 64, 56, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.005, p)); c.stroke();
            }
            Text {
                anchors.centerIn: parent
                text: Chrono.text
                color: Chrono.running ? "#FFFFFF" : "#8E8E93"
                font.family: Theme.font
                font.pixelSize: 26
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
            }
        }
        Column {
            anchors.left: ring.right
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                text: Chrono.mode === "pomodoro" ? Chrono.phase : Chrono.mode === "stopwatch" ? "Stopwatch" : "Timer"
                color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold
            }
            Text {
                text: Chrono.mode === "pomodoro" ? "Round " + Chrono.round + " of 4" + (Chrono.running ? "" : " · paused")
                    : !Chrono.running ? "Paused" : Chrono.mode === "countdown" ? "of " + Chrono.fmt(Chrono.total) : "Running"
                color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
            }
            Item { width: 1; height: 8 }
            Row {
                spacing: 8
                Ctl { icon: Chrono.running ? "pause" : "play"; primary: true; onClicked: Chrono.toggle() }
                Ctl { icon: "plus"; visible: Chrono.mode !== "stopwatch"; onClicked: Chrono.addMinute() }
                Ctl { icon: "stop"; onClicked: Chrono.stop() }
            }
        }
    }

    component Big: Rectangle {
        id: b
        property string icon: ""
        property string title: ""
        property string sub: ""
        signal clicked()
        width: (root.width - 10) / 2
        height: 62; radius: 18
        color: bm.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
        scale: bm.pressed ? 0.97 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35 } }
        Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 38; radius: 12; color: Theme.tint(0.25); Icon { anchors.centerIn: parent; name: b.icon; size: 18 } }
        Column {
            x: 62; anchors.verticalCenter: parent.verticalCenter
            Text { text: b.title; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text { text: b.sub; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
    component Ctl: Rectangle {
        id: cbtn
        property string icon: ""
        property bool primary: false
        signal clicked()
        width: 42; height: 42; radius: 21
        color: primary ? (cm.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent) : (cm.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1))
        scale: cm.pressed ? 0.9 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35 } }
        Icon { anchors.centerIn: parent; name: cbtn.icon; size: 17 }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cbtn.clicked() }
    }
}
