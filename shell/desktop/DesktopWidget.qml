import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"
import "../common"

// Một widget trên màn hình nền (thẻ kính mờ). Kéo để dời; rê chuột vào thì hiện nút gỡ.
//   kind: clock | calendar | weather | system
Item {
    id: root
    property string kind: ""
    signal moved(real x, real y)
    signal removeRequested()

    HoverHandler { id: hov }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 26
        color: Qt.rgba(0.07, 0.07, 0.11, 0.42)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
        scale: root.dragging ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: root
        drag.threshold: 6
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onReleased: if (drag.active || Math.abs(root.x - px) > 1 || Math.abs(root.y - py) > 1) root.moved(root.x, root.y)
        property real px: 0; property real py: 0
        onPressed: { px = root.x; py = root.y; }
        onClicked: if (root.kind === "calendar") Ui.openIsland("calendar")
                   else if (root.kind === "system") Ui.toggleTask()
                   else if (root.kind === "clock") Ui.openSettings("datetime")
        // thả xong: giữ trong màn hình
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: (root.parent?.width ?? 2000) - root.width
        drag.maximumY: (root.parent?.height ?? 2000) - root.height
    }
    readonly property bool dragging: dragArea.drag.active

    Loader {
        anchors.fill: parent
        anchors.margins: 20
        sourceComponent: root.kind === "clock" ? clockC : root.kind === "calendar" ? calC : root.kind === "weather" ? weatherC : sysC
    }

    // nút gỡ (rê chuột vào mới hiện)
    Rectangle {
        x: -7; y: -7; width: 24; height: 24; radius: 12
        color: rmA.containsMouse ? "#FF5F57" : Qt.rgba(0.2, 0.2, 0.25, 0.95)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
        opacity: hov.hovered && !root.dragging ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Icon { anchors.centerIn: parent; name: "minus"; size: 13 }
        MouseArea { id: rmA; anchors.fill: parent; hoverEnabled: true; onClicked: root.removeRequested() }
    }

    // ================= đồng hồ =================
    Component {
        id: clockC
        Item {
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: Time.weekdayUpper; color: Qt.lighter(Theme.accent, 1.35); font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 1.5 }
                Text { text: Time.time; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 58; font.weight: Font.Light; lineHeight: 0.9 }
                Text { text: Time.dayMonth + " · " + Time.now.getFullYear(); color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 14 }
            }
        }
    }

    // ================= lịch tháng =================
    Component {
        id: calC
        Column {
            id: cal
            spacing: 8
            readonly property date today: Time.now
            readonly property int y_: today.getFullYear()
            readonly property int m_: today.getMonth()
            readonly property int first: (new Date(y_, m_, 1).getDay() + 6) % 7       // thứ Hai đầu tuần
            readonly property int days: new Date(y_, m_ + 1, 0).getDate()
            Row {
                width: parent.width
                Text { text: Time.monthLong[cal.m_]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold }
                Text { text: "  " + cal.y_; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 16 }
            }
            Grid {
                columns: 7
                rowSpacing: 2
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Text { required property string modelData; width: 37; horizontalAlignment: Text.AlignHCenter; text: modelData; color: "#636366"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold }
                }
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int d: index - cal.first + 1
                        readonly property bool inMonth: d >= 1 && d <= cal.days
                        readonly property bool isToday: d === cal.today.getDate()
                        readonly property string k: inMonth ? Calendar.key(new Date(cal.y_, cal.m_, d)) : ""
                        visible: index < Math.ceil((cal.first + cal.days) / 7) * 7
                        width: 37; height: 26
                        Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: Theme.accent; visible: parent.inMonth && parent.isToday }
                        Text {
                            anchors.centerIn: parent
                            text: parent.inMonth ? parent.d : ""
                            color: parent.isToday ? "#FFFFFF" : (parent.index % 7 >= 5 ? "#8E8E93" : "#E5E5EA")
                            font.family: Theme.font; font.pixelSize: 12; font.weight: parent.isToday ? Font.Bold : Font.Normal
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                            width: 4; height: 4; radius: 2; color: Qt.lighter(Theme.accent, 1.3)
                            visible: parent.inMonth && !parent.isToday && Calendar.pending(parent.k) > 0
                        }
                    }
                }
            }
        }
    }

    // ================= thời tiết =================
    Component {
        id: weatherC
        Item {
            id: wx
            Component.onCompleted: Weather.active = true
            Component.onDestruction: Weather.active = false
            function deg(c) { return isNaN(c) ? "—" : Math.round(Prefs.tempF ? c * 9 / 5 + 32 : c) + "°"; }
            Column {
                width: parent.width
                spacing: 10
                Item {
                    width: parent.width; height: 62
                    Column {
                        Text { text: Weather.place || Weather.city || "Weather"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: wx.deg(Weather.temp); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 40; font.weight: Font.Light }
                    }
                    Column {
                        anchors.right: parent.right
                        spacing: 4
                        Icon { anchors.right: parent.right; name: Weather.code >= 0 ? Weather.icon(Weather.code, Weather.day) : "cloud"; size: 30 }
                        Text { anchors.right: parent.right; text: Weather.error || (Weather.code >= 0 ? Weather.label(Weather.code) : "Loading…"); color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12 }
                        Text {
                            anchors.right: parent.right
                            visible: Weather.daily.length > 0
                            text: Weather.daily.length ? "H " + wx.deg(Weather.daily[0].max) + "  L " + wx.deg(Weather.daily[0].min) : ""
                            color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                Row {
                    width: parent.width
                    Repeater {
                        model: Weather.daily.slice(1, 5)
                        Column {
                            required property var modelData
                            width: parent.width / 4
                            spacing: 3
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Time.dayShort[new Date(modelData.date + "T12:00").getDay()]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.icon(modelData.code, true); size: 18 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(Prefs.tempF ? modelData.max * 9 / 5 + 32 : modelData.max) + "°"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }

    // ================= CPU & bộ nhớ (đọc /proc, nhẹ) =================
    Component {
        id: sysC
        Item {
            id: sys
            property real cpu: 0
            property real memUsed: 0
            property real memTotal: 1
            property var prev: null
            FileView { id: stat; path: "/proc/stat"; printErrors: false }
            FileView { id: meminfo; path: "/proc/meminfo"; printErrors: false }
            Timer {
                interval: 2000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    stat.reload(); meminfo.reload();
                    const c = (stat.text().split("\n")[0] || "").trim().split(/\s+/).slice(1).map(Number);
                    if (c.length >= 4) {
                        const idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0);
                        if (sys.prev) {
                            const dt = total - sys.prev.total;
                            if (dt > 0) sys.cpu = Math.max(0, Math.min(1, 1 - (idle - sys.prev.idle) / dt));
                        }
                        sys.prev = { idle: idle, total: total };
                    }
                    const m = {};
                    for (const l of meminfo.text().split("\n")) { const p = l.match(/^(\w+):\s+(\d+)/); if (p) m[p[1]] = Number(p[2]) * 1024; }
                    if (m.MemTotal) { sys.memTotal = m.MemTotal; sys.memUsed = m.MemTotal - (m.MemAvailable ?? m.MemFree); }
                }
            }
            function gb(b) { return (b / 1073741824).toFixed(1); }
            Column {
                width: parent.width
                spacing: 14
                Repeater {
                    model: [
                        { label: "CPU", value: sys.cpu, text: Math.round(sys.cpu * 100) + "%", icon: "cpu" },
                        { label: "Memory", value: sys.memUsed / sys.memTotal, text: sys.gb(sys.memUsed) + " / " + sys.gb(sys.memTotal) + " GB", icon: "layers" }
                    ]
                    Column {
                        required property var modelData
                        width: parent.width
                        spacing: 6
                        Item {
                            width: parent.width; height: 18
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.icon; size: 15; opacity: 0.8 }
                            Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.text; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12 }
                        }
                        Rectangle {
                            width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1)
                            Rectangle {
                                height: parent.height; radius: 4
                                width: Math.max(8, parent.width * Math.min(1, modelData.value))
                                color: modelData.value > 0.85 ? "#FF5F57" : modelData.value > 0.6 ? "#FFB547" : Theme.accent
                                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }
    }
}
