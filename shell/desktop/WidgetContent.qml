import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"
import "../common"

// Ruột của một widget màn hình nền. Dùng cho cả widget thật lẫn ô xem trước trong cửa sổ Widgets.
//   kind: clock | analog | world | calendar | timer | weather | media | photo | launch
//         | system | disk | net | battery | sysinfo
//   conf: cài riêng của widget đó (múi giờ, thư mục ảnh…) · preview: ô xem trước (không đụng vào hệ thống)
Item {
    id: root
    property string kind: ""
    property var conf: ({})
    property bool preview: false
    signal configure()

    Loader {
        anchors.fill: parent
        sourceComponent: root.kind === "clock" ? clockC : root.kind === "analog" ? analogC
            : root.kind === "world" ? worldC : root.kind === "calendar" ? calC : root.kind === "timer" ? timerC
            : root.kind === "weather" ? weatherC : root.kind === "media" ? mediaC : root.kind === "photo" ? photoC
            : root.kind === "launch" ? launchC : root.kind === "system" ? sysC : root.kind === "disk" ? diskC
            : root.kind === "net" ? netC : root.kind === "battery" ? battC : sysInfoC
    }

    // ---- dùng chung ----
    component Title: Text { color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
    component Sub: Text { color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
    component Bar: Rectangle {
        id: br
        property real value: 0
        property color fill: Theme.accent
        height: 8; radius: 4
        color: Qt.rgba(1, 1, 1, 0.1)
        Rectangle {
            height: br.height; radius: 4
            width: Math.max(8, br.width * Math.max(0, Math.min(1, br.value)))
            color: br.fill
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
    }
    component Meter: Column {
        id: mt
        property string label: ""
        property string text_: ""
        property real value: 0
        property string icon: ""
        property color fill: value > 0.85 ? "#FF5F57" : value > 0.6 ? "#FFB547" : Theme.accent
        width: parent ? parent.width : 200
        spacing: 6
        Item {
            width: mt.width; height: 18
            Icon { anchors.verticalCenter: parent.verticalCenter; name: mt.icon; size: 15; opacity: 0.8 }
            Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: mt.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: mt.text_; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12 }
        }
        Bar { width: mt.width; value: mt.value; fill: mt.fill }
    }

    // ================= đồng hồ số =================
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

    // ================= đồng hồ kim =================
    Component {
        id: analogC
        Item {
            id: an
            readonly property date now: Time.now
            readonly property real r: Math.min(width, height) / 2 - 4
            Rectangle {
                anchors.centerIn: parent
                width: an.r * 2; height: an.r * 2; radius: an.r
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                // vạch giờ
                Repeater {
                    model: 12
                    Rectangle {
                        required property int index
                        readonly property real a: index * Math.PI / 6
                        width: index % 3 === 0 ? 3 : 2
                        height: index % 3 === 0 ? 9 : 5
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, index % 3 === 0 ? 0.65 : 0.3)
                        x: parent.width / 2 - width / 2 + Math.sin(a) * (an.r - 11)
                        y: parent.height / 2 - height / 2 - Math.cos(a) * (an.r - 11)
                        rotation: index * 30
                    }
                }
                // kim
                Repeater {
                    model: [
                        { len: 0.52, w: 4,   col: "#FFFFFF", ang: (an.now.getHours() % 12 + an.now.getMinutes() / 60) * 30 },
                        { len: 0.74, w: 3,   col: "#FFFFFF", ang: (an.now.getMinutes() + an.now.getSeconds() / 60) * 6 },
                        { len: 0.80, w: 1.5, col: Theme.accent, ang: an.now.getSeconds() * 6 }
                    ]
                    Rectangle {
                        required property var modelData
                        width: modelData.w
                        height: an.r * modelData.len
                        radius: width / 2
                        color: modelData.col
                        x: parent.width / 2 - width / 2
                        y: parent.height / 2 - height
                        transformOrigin: Item.Bottom
                        rotation: modelData.ang
                        Behavior on rotation { enabled: Math.abs(rotation) < 350; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
                Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 4; color: Theme.accent }
            }
        }
    }

    // ================= đồng hồ thế giới =================
    Component {
        id: worldC
        Item {
            id: wc
            readonly property var zones: root.conf?.zones ?? ["Asia/Ho_Chi_Minh", "Asia/Tokyo", "Europe/London", "America/New_York"]
            property var times: []
            function pull() {
                if (clockProc.running) return;
                clockProc.command = ["sh", "-c", wc.zones.map(z => `TZ='${z}' date +%H:%M$'\\t'%a`).join("; ")];
                clockProc.running = true;
            }
            Component.onCompleted: pull()
            Connections { target: Time; function onTimeChanged() { wc.pull(); } }
            Process {
                id: clockProc
                stdout: StdioCollector { onStreamFinished: wc.times = text.split("\n").filter(x => x).map(l => l.split("\t")) }
            }
            Column {
                anchors.fill: parent
                spacing: 7
                Repeater {
                    model: wc.zones.length
                    Item {
                        required property int index
                        width: parent.width; height: 26
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 90; elide: Text.ElideRight
                            text: wc.zones[index].split("/").pop().replace(/_/g, " ")
                            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: wc.times[index] ? wc.times[index][0] : "--:--"
                            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Medium
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 58; anchors.verticalCenter: parent.verticalCenter
                            text: wc.times[index] ? wc.times[index][1] : ""
                            color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                        }
                    }
                }
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

    // ================= hẹn giờ =================
    Component {
        id: timerC
        Item {
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 10
                Row {
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "timer"; size: 16; opacity: 0.85 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Chrono.active ? (Chrono.phase || (Chrono.mode === "stopwatch" ? "Stopwatch" : "Timer")) : "Timer"
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Chrono.mode === "pomodoro"
                        text: "round " + Chrono.round; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                    }
                }
                Text {
                    text: Chrono.active ? Chrono.text : "--:--"
                    color: Chrono.active ? "#FFFFFF" : "#636366"
                    font.family: Theme.font; font.pixelSize: 38; font.weight: Font.Light
                }
                Row {
                    spacing: 7
                    visible: !root.preview
                    Repeater {
                        model: Chrono.active ? [[Chrono.running ? "Pause" : "Resume", "toggle"], ["Stop", "stop"]]
                                             : [["5 min", "c5"], ["25 min", "c25"], ["Pomodoro", "pomo"]]
                        Rectangle {
                            required property var modelData
                            width: tl.implicitWidth + 18; height: 24; radius: 12
                            color: tm.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                            Text { id: tl; anchors.centerIn: parent; text: parent.modelData[0]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                            MouseArea {
                                id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = parent.modelData[1];
                                    if (a === "toggle") Chrono.toggle();
                                    else if (a === "stop") Chrono.stop();
                                    else if (a === "c5") Chrono.countdown(5);
                                    else if (a === "c25") Chrono.countdown(25);
                                    else Chrono.pomodoro();
                                }
                            }
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
            Component.onCompleted: if (!root.preview) Weather.active = true
            Component.onDestruction: if (!root.preview) Weather.active = false
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

    // ================= đang phát =================
    Component {
        id: mediaC
        Item {
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 10
                visible: Media.hasPlayer || root.preview
                Row {
                    width: parent.width
                    spacing: 12
                    Rectangle {
                        width: 54; height: 54; radius: 12; clip: true
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(108, 108); asynchronous: true }
                        Icon { anchors.centerIn: parent; visible: !Media.artUrl; name: "music"; size: 22; opacity: 0.6 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 66
                        spacing: 2
                        Text { width: parent.width; elide: Text.ElideRight; text: Media.hasPlayer ? Media.title : "Nothing playing"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18
                    visible: !root.preview
                    Repeater {
                        model: [["prev", "prev"], [Media.playing ? "pause" : "play", "toggle"], ["next", "next"]]
                        Item {
                            required property var modelData
                            width: 26; height: 26
                            Icon { anchors.centerIn: parent; name: parent.modelData[0]; size: parent.modelData[1] === "toggle" ? 22 : 18; opacity: mm.containsMouse ? 1 : 0.8 }
                            MouseArea {
                                id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { const a = parent.modelData[1]; if (a === "prev") Media.previous(); else if (a === "next") Media.next(); else Media.toggle(); }
                            }
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: !Media.hasPlayer && !root.preview
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "music"; size: 26; opacity: 0.45 }
                Text { text: "Nothing playing"; color: "#636366"; font.family: Theme.font; font.pixelSize: 12 }
            }
        }
    }

    // ================= khung ảnh =================
    Component {
        id: photoC
        Item {
            id: ph
            readonly property string dir: root.conf?.dir || (Quickshell.env("HOME") + "/Pictures")
            readonly property int secs: root.conf?.secs || 20
            property var pics: []
            property int idx: 0
            property bool flip: false
            Process {
                id: scan
                running: true
                command: ["sh", "-c", 'find "$0" -maxdepth 2 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) 2>/dev/null | head -200', ph.dir]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const l = text.split("\n").filter(x => x);
                        for (let i = l.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [l[i], l[j]] = [l[j], l[i]]; }
                        ph.pics = l;
                        if (l.length) { imgA.source = "file://" + l[0]; ph.flip = true; }
                    }
                }
            }
            Timer {
                interval: ph.secs * 1000
                repeat: true
                running: ph.pics.length > 1 && !root.preview
                onTriggered: {
                    ph.idx = (ph.idx + 1) % ph.pics.length;
                    ph.flip = !ph.flip;
                    (ph.flip ? imgA : imgB).source = "file://" + ph.pics[ph.idx];
                }
            }
            Rectangle {
                anchors.fill: parent; radius: 14; clip: true
                color: Qt.rgba(1, 1, 1, 0.05)
                Image { id: imgA; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(560, 440); opacity: ph.flip ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 900 } } }
                Image { id: imgB; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(560, 440); opacity: ph.flip ? 0 : 1; Behavior on opacity { NumberAnimation { duration: 900 } } }
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: ph.pics.length === 0
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "image"; size: 26; opacity: 0.45 }
                    Text { text: root.preview ? "Your pictures" : "No pictures in " + ph.dir.split("/").pop(); color: "#636366"; font.family: Theme.font; font.pixelSize: 11 }
                }
            }
        }
    }

    // ================= mở nhanh =================
    Component {
        id: launchC
        Item {
            Row {
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: DockPins.pins.slice(0, 6)
                    Item {
                        id: li
                        required property string modelData
                        width: 44; height: 60
                        AppIcon {
                            id: ic
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 40
                            name: li.modelData
                            scale: lm.containsMouse ? 1.12 : 1
                            Behavior on scale { SpringAnimation { spring: 5; damping: 0.35 } }
                        }
                        MouseArea {
                            id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: if (!root.preview) Ui.launchEntry(DesktopEntries.byId(li.modelData) ?? DesktopEntries.heuristicLookup(li.modelData))
                        }
                    }
                }
            }
        }
    }

    // ================= CPU & bộ nhớ =================
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
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 14
                Meter { icon: "cpu"; label: "CPU"; value: sys.cpu; text_: Math.round(sys.cpu * 100) + "%" }
                Meter { icon: "layers"; label: "Memory"; value: sys.memUsed / sys.memTotal; text_: sys.gb(sys.memUsed) + " / " + sys.gb(sys.memTotal) + " GB" }
            }
        }
    }

    // ================= ổ đĩa =================
    Component {
        id: diskC
        Item {
            id: dk
            property var rows: []
            Process {
                id: dfp
                running: true
                command: ["sh", "-c", "df -B1 --output=target,size,used 2>/dev/null | tail -n +2"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const seen = [];
                        dk.rows = text.split("\n").filter(x => x.trim()).map(l => {
                            const p = l.trim().split(/\s+/);
                            return { mount: p[0], size: Number(p[1]), used: Number(p[2]) };
                        }).filter(r => r.size > 5e8 && (r.mount === "/" || r.mount === "/home" || r.mount.startsWith("/run/media")))
                          .filter(r => seen.indexOf(r.mount) < 0 && seen.push(r.mount))
                          .slice(0, 2);
                    }
                }
            }
            Timer { interval: 60000; repeat: true; running: !root.preview; onTriggered: dfp.running = true }
            function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : Math.round(b / 1e9) + " GB"; }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 14
                Repeater {
                    model: dk.rows
                    Meter {
                        required property var modelData
                        icon: "disk"
                        label: modelData.mount === "/" ? "System" : modelData.mount.split("/").pop()
                        value: modelData.used / modelData.size
                        text_: dk.gb(modelData.size - modelData.used) + " free"
                    }
                }
                Text { visible: dk.rows.length === 0; text: "No drives"; color: "#636366"; font.family: Theme.font; font.pixelSize: 12 }
            }
        }
    }

    // ================= mạng =================
    Component {
        id: netC
        Item {
            id: nt
            property real rx: 0
            property real tx: 0
            property var prev: null
            FileView { id: netdev; path: "/proc/net/dev"; printErrors: false }
            Timer {
                interval: 2000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    netdev.reload();
                    let r = 0, t = 0;
                    for (const l of netdev.text().split("\n")) {
                        const m = l.match(/^\s*([\w@-]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
                        if (m && m[1] !== "lo") { r += Number(m[2]); t += Number(m[3]); }
                    }
                    const now = Date.now();
                    if (nt.prev) {
                        const dt = Math.max(0.5, (now - nt.prev.t) / 1000);
                        nt.rx = Math.max(0, (r - nt.prev.r) / dt);
                        nt.tx = Math.max(0, (t - nt.prev.x) / dt);
                    }
                    nt.prev = { r: r, x: t, t: now };
                }
            }
            function rate(b) {
                if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
                if (b >= 1024) return Math.round(b / 1024) + " KB/s";
                return Math.round(b) + " B/s";
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 12
                Row {
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: Net.icon; size: 15; opacity: 0.85 }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 230; elide: Text.ElideRight; text: Net.connected ? Net.label : "Offline"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                Row {
                    width: parent.width
                    Column {
                        width: parent.width / 2
                        spacing: 2
                        Row { spacing: 6; Icon { anchors.verticalCenter: parent.verticalCenter; name: "download"; size: 13; opacity: 0.7 } Text { text: "Down"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 } }
                        Text { text: nt.rate(nt.rx); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Medium }
                    }
                    Column {
                        width: parent.width / 2
                        spacing: 2
                        Row { spacing: 6; Icon { anchors.verticalCenter: parent.verticalCenter; name: "download"; size: 13; opacity: 0.7; rotation: 180 } Text { text: "Up"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 } }
                        Text { text: nt.rate(nt.tx); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Medium }
                    }
                }
            }
        }
    }

    // ================= pin =================
    Component {
        id: battC
        Item {
            readonly property real pct: Power.present ? Power.percent : 1
            readonly property real secsLeft: Power.charging ? (Power.dev?.timeToFull ?? 0) : (Power.dev?.timeToEmpty ?? 0)
            function left() {
                const s = secsLeft;
                if (!Power.present) return "No battery";
                if (s <= 0) return Power.charging ? "Charging" : "Calculating…";
                const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
                return (h > 0 ? h + "h " + m + "m" : m + "m") + (Power.charging ? " to full" : " left");
            }
            id: bt
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 10
                Row {
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: Power.charging ? "bolt" : "battery"; size: 16; opacity: 0.85 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                Text {
                    text: Power.present ? Math.round(bt.pct * 100) + "%" : "—"
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 32; font.weight: Font.Light
                }
                Bar {
                    width: parent.width
                    value: bt.pct
                    fill: Power.charging ? "#34C77B" : bt.pct < 0.15 ? "#FF5F57" : bt.pct < 0.3 ? "#FFB547" : Theme.accent
                }
                Text { text: bt.left(); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
            }
        }
    }

    // ================= máy này =================
    Component {
        id: sysInfoC
        Item {
            id: si
            property var info: ({})
            Process {
                running: true
                command: ["sh", "-c",
                    ". /etc/os-release 2>/dev/null; echo \"os=${PRETTY_NAME:-Islet}\"; echo \"host=$(cat /etc/hostname 2>/dev/null)\"; "
                    + "echo \"kernel=$(uname -r)\"; echo \"up=$(cut -d. -f1 /proc/uptime)\"; "
                    + "echo \"ver=$(pacman -Q islet 2>/dev/null | awk '{print $2}')\""]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const o = {};
                        for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); }
                        si.info = o;
                    }
                }
            }
            function uptime() {
                const s = Number(si.info.up || 0);
                const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
                return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 14
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46; height: 46; sourceSize: Qt.size(92, 92)
                    source: Qt.resolvedUrl("../assets/brand/cat.svg")
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 60
                    spacing: 2
                    Text { width: parent.width; elide: Text.ElideRight; text: si.info.host || "Islet"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold }
                    Text { width: parent.width; elide: Text.ElideRight; text: si.info.ver ? "Islet " + si.info.ver : (si.info.os || "Islet"); color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12 }
                    Text { width: parent.width; elide: Text.ElideRight; text: "Linux " + (si.info.kernel || "") ; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                    Text { text: "Up " + si.uptime(); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                }
            }
        }
    }
}
