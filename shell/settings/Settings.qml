import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../theme"
import "../services"
import "../common"
import "../controlcenter"
import "../wallpaper"

// App Cài đặt của Islet: Hình nền · Màu nhấn · Wi-Fi · Âm thanh · Màn hình · Giới thiệu.
// Mở: "Cài đặt" trên dock, nút bánh răng ở trung tâm điều khiển, hoặc `islet-ipc settings open`.
PanelWindow {
    id: win

    implicitWidth: 900
    implicitHeight: 620
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property bool open: Ui.settingsOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    readonly property string page: Ui.settingsPage
    readonly property var pages: [
        { id: "wallpaper", label: "Wallpaper",   icon: "palette",  tint: "#B65CFF" },
        { id: "accent",    label: "Accent color",   icon: "sparkle",  tint: "#FF6B97" },
        { id: "wifi",      label: "Wi-Fi",      icon: "wifi",     tint: "#3B8BFF" },
        { id: "sound",     label: "Sound",   icon: "volume",   tint: "#FF5C7A" },
        { id: "display",   label: "Displays",   icon: "sun",      tint: "#FFB547" },
        { id: "about",     label: "About", icon: "islet",    tint: "#8B7CFF" }
    ]

    onOpenChanged: if (open) { panel.forceActiveFocus(); refreshPage(); }
    onPageChanged: if (open) refreshPage()
    function refreshPage() {
        if (page === "wallpaper") pics.running = true;
        if (page === "wifi") wifi.refresh(true);
        if (page === "display") mons.running = true;
        if (page === "about") about.running = true;
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Ui.settingsOpen = false
    }

    // ================= dữ liệu =================
    // ảnh nền có sẵn trên máy
    property var pictures: []
    Process {
        id: pics
        command: ["sh", "-c", "for d in /usr/share/islet/wallpapers /usr/share/backgrounds \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures\" \"$HOME/Ảnh\"; do [ -d \"$d\" ] && find \"$d\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null; done | head -60"]
        stdout: StdioCollector { onStreamFinished: win.pictures = text.split("\n").filter(x => x) }
    }

    // màn hình (hyprctl)
    property var monitors: []
    Process {
        id: mons
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { win.monitors = JSON.parse(text); } catch (e) {} } }
    }

    // giới thiệu
    property var sys: ({})
    Process {
        id: about
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "os=\${PRETTY_NAME:-Islet}"
            echo "host=$(cat /etc/hostname 2>/dev/null)"
            echo "kernel=$(uname -r)"
            echo "cpu=$(sed -n 's/^model name\\s*: //p' /proc/cpuinfo | head -1)"
            echo "cores=$(nproc)"
            echo "ram=$(awk '/MemTotal/{printf "%.1f GB", $2/1048576}' /proc/meminfo)"
            echo "gpu=$(lspci 2>/dev/null | sed -n 's/.*\\(VGA\\|3D\\|Display\\)[^:]*: //p' | head -1)"
            echo "disk=$(df -h / | awk 'NR==2{print $3 " / " $2}')"
            echo "hypr=$(hyprctl version 2>/dev/null | sed -n 's/^Hyprland \\([0-9.]*\\).*/\\1/p' | head -1)"
            awk '{s=int($1); d=int(s/86400); h=int(s%86400/3600); m=int(s%3600/60); printf "up="; if (d) printf "%dd ", d; if (h) printf "%dh ", h; printf "%d min\n", m}' /proc/uptime
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                text.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); });
                win.sys = o;
            }
        }
    }

    // Wi-Fi (islet-wifi)
    QtObject {
        id: wifi
        property string dev: ""
        property string state: ""
        property string current: ""
        property var nets: []
        property string joining: ""      // mạng đang chờ nhập mật khẩu
        property string busy: ""         // mạng đang kết nối
        property string error: ""
        function refresh(scan) {
            if (scan) Quickshell.execDetached(["islet-wifi", "scan"]);
            wst.running = true;
            rescan.restart();
        }
        function connect(name, pw) {
            busy = name; error = "";
            wcon.name = name;
            wcon.pw = pw || "";
            wcon.running = true;
        }
    }
    Timer { id: rescan; interval: 2500; onTriggered: wlist.running = true }
    Timer { interval: 8000; repeat: true; running: win.open && win.page === "wifi"; onTriggered: { wst.running = true; wlist.running = true; } }
    Process {
        id: wst
        command: ["islet-wifi", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\t");
                wifi.dev = p[0] || ""; wifi.state = p[1] || ""; wifi.current = p[2] || "";
            }
        }
    }
    Process {
        id: wlist
        command: ["islet-wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifi.nets = text.split("\n").filter(x => x).map(l => {
                    const p = l.split("\t");
                    return { name: p[0], sec: p[1], q: parseInt(p[2]) || 0, cur: p[3] === "1", saved: p[4] === "1" };
                }).sort((a, b) => (b.cur - a.cur) || (b.q - a.q));
            }
        }
    }
    Process {
        id: wcon
        property string name: ""
        property string pw: ""
        command: ["islet-wifi", "connect", name]
        stdinEnabled: true
        onStarted: { write(pw + "\n"); stdinEnabled = false; }
        stderr: StdioCollector { id: wconErr }
        onExited: code => {
            stdinEnabled = true;
            if (code === 0) { wifi.joining = ""; wifi.error = ""; Ui.toast("Connected to " + wifi.busy, "", ""); }
            else if (code === 3) { wifi.joining = wifi.busy; wifi.error = "Wrong password"; }
            else wifi.error = wconErr.text.trim() || "Couldn't connect";
            wifi.busy = "";
            wst.running = true; wlist.running = true; Net.refresh();
        }
    }

    // Âm thanh
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    PwObjectTracker { objects: win.sinks.concat(win.sources) }

    // Màn hình: đổi xong thì hỏi giữ lại, quá 12 giây không trả lời thì quay về
    property var pendingRevert: null      // { name, prev }
    property int revertLeft: 0
    Timer {
        id: revertTick
        interval: 1000; repeat: true
        running: win.pendingRevert !== null
        onTriggered: { win.revertLeft -= 1; if (win.revertLeft <= 0) win.revertMonitor(); }
    }
    function setMonitor(name, patch) {
        const cur = monitors.find(m => m.name === name);
        const prev = Object.assign({}, Prefs.monitors[name] ?? {
            mode: cur ? cur.width + "x" + cur.height + "@" + Math.round(cur.refreshRate) : "preferred",
            scale: cur?.scale ?? 1
        });
        const next = Object.assign({}, prev, patch);
        const all = Object.assign({}, Prefs.monitors);
        all[name] = next;
        if (!pendingRevert) pendingRevert = { name: name, prev: prev };
        revertLeft = 12;
        Prefs.set("monitors", all);
        remon.restart();
    }
    function keepMonitor() { pendingRevert = null; }
    function revertMonitor() {
        if (!pendingRevert) return;
        const all = Object.assign({}, Prefs.monitors);
        all[pendingRevert.name] = pendingRevert.prev;
        pendingRevert = null;
        Prefs.set("monitors", all);
        remon.restart();
    }
    Timer { id: remon; interval: 900; onTriggered: mons.running = true }

    // ================= khung =================
    Glass {
        id: panel
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0.05, 0.05, 0.09, 0.9)

        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.002 } }

        Keys.onEscapePressed: Ui.settingsOpen = false

        // ---------- cột trái ----------
        Rectangle {
            id: side
            width: 210
            height: parent.height
            radius: 28
            color: Qt.rgba(1, 1, 1, 0.03)

            Row {
                x: 20; y: 22; spacing: 10
                Image { width: 32; height: 32; sourceSize: Qt.size(64, 64); source: Theme.appIcon("settings") }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Settings"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
            }

            Column {
                x: 12; y: 74
                width: parent.width - 24
                spacing: 3
                Repeater {
                    model: win.pages
                    Rectangle {
                        id: nav
                        required property var modelData
                        readonly property bool on: win.page === modelData.id
                        width: parent.width
                        height: 40
                        radius: 13
                        color: on ? Theme.tint(0.22) : nm.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Rectangle {
                            x: 10; anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26; radius: 8
                            // Tối giản: ô than, trang đang mở mang màu nhấn · Sắc màu: mỗi trang một màu
                            color: Prefs.iconStyle === "color" ? nav.modelData.tint : nav.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.09)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Icon { anchors.centerIn: parent; name: nav.modelData.icon; size: 15 }
                        }
                        Text { x: 46; anchors.verticalCenter: parent.verticalCenter; text: nav.modelData.label; color: nav.on ? "#FFFFFF" : "#D1D1D6"; font.family: Theme.font; font.pixelSize: 13; font.weight: nav.on ? Font.DemiBold : Font.Normal }
                        MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.settingsPage = nav.modelData.id }
                    }
                }
            }
        }

        // nút đóng
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.top: parent.top; anchors.topMargin: 16
            width: 32; height: 32; radius: 16
            z: 5
            color: xm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
            Icon { anchors.centerIn: parent; name: "close"; size: 14 }
            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.settingsOpen = false }
        }

        // ---------- nội dung ----------
        Flickable {
            id: flick
            anchors.left: side.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 22
            anchors.leftMargin: 26
            contentHeight: body.implicitHeight + 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: flick.width
                spacing: 16

                // hiệu ứng đổi trang: trượt lên + hiện dần
                property string shownPage: win.page
                opacity: 1
                Connections {
                    target: win
                    function onPageChanged() { flick.contentY = 0; pageIn.restart(); }
                }
                ParallelAnimation {
                    id: pageIn
                    NumberAnimation { target: body; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { target: body; property: "y"; from: 14; to: 0; duration: 320; easing.type: Easing.OutCubic }
                }

                Text {
                    text: (win.pages.find(p => p.id === win.page) ?? {}).label ?? ""
                    color: "#FFFFFF"
                    font.family: Theme.font
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }

                // ================= HÌNH NỀN =================
                Column {
                    visible: win.page === "wallpaper"
                    width: parent.width
                    spacing: 16

                    // xem trước: màn hình nhỏ có thanh trên + dock
                    Rounded {
                        width: parent.width
                        height: width * 0.42
                        radius: 18
                        Backdrop { anchors.fill: parent }
                        Rectangle { x: parent.width / 2 - 50; y: 6; width: 100; height: 16; radius: 8; color: "#000000" }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                            width: 150; height: 22; radius: 9
                            color: Qt.rgba(1, 1, 1, 0.16)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
                            Row {
                                anchors.centerIn: parent; spacing: 5
                                Repeater { model: 6; Rectangle { width: 15; height: 15; radius: 5; color: Qt.rgba(1, 1, 1, 0.55 + index * 0.05) } }
                            }
                        }
                    }

                    SectionLabel { text: "Live wallpapers" }
                    Flow {
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: Prefs.presets
                            Item {
                                id: pv
                                required property var modelData
                                readonly property bool on: Prefs.wallpaper === "preset:" + modelData.id
                                width: (body.width - 24) / 3
                                height: width * 0.62 + 24
                                Item {
                                    id: thumb
                                    width: parent.width
                                    height: parent.width * 0.62
                                    scale: pm.pressed ? 0.95 : pm.containsMouse ? 1.03 : 1
                                    Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.002 } }
                                    Rounded { anchors.fill: parent; radius: 14; Backdrop { anchors.fill: parent; preset: pv.modelData; image: ""; animated: false } }
                                    Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.width: pv.on ? 3 : 1; border.color: pv.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.08) }
                                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("wallpaper", "preset:" + pv.modelData.id) }
                                }
                                Text { anchors.top: thumb.bottom; anchors.topMargin: 5; text: pv.modelData.label; color: pv.on ? "#FFFFFF" : "#AEAEB2"; font.family: Theme.font; font.pixelSize: 12; font.weight: pv.on ? Font.DemiBold : Font.Normal }
                            }
                        }
                    }

                    SectionLabel { text: "Photos"; visible: win.pictures.length > 0 }
                    Flow {
                        visible: win.pictures.length > 0
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: win.pictures
                            Item {
                                id: ph
                                required property string modelData
                                readonly property bool on: Prefs.wallpaper === modelData
                                width: (body.width - 36) / 4
                                height: width * 0.62
                                scale: phm.pressed ? 0.95 : phm.containsMouse ? 1.03 : 1
                                Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.002 } }
                                Rounded {
                                    anchors.fill: parent
                                    radius: 12
                                    Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.06) }
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + ph.modelData
                                        sourceSize: Qt.size(320, 200)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.width: ph.on ? 3 : 1; border.color: ph.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.08) }
                                MouseArea { id: phm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("wallpaper", ph.modelData) }
                            }
                        }
                    }
                    Hint { text: "Add your own images to ~/Pictures/Wallpapers and they will show up here." }
                }

                // ================= MÀU NHẤN =================
                Column {
                    visible: win.page === "accent"
                    width: parent.width
                    spacing: 18

                    Row {
                        spacing: 14
                        Repeater {
                            model: Prefs.accents
                            Column {
                                id: sw
                                required property var modelData
                                readonly property bool on: Prefs.accentId === modelData.id
                                spacing: 7
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 46; height: 46; radius: 23
                                    color: "transparent"
                                    border.width: sw.on ? 2.5 : 0
                                    border.color: sw.modelData.color
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: sw.on ? 34 : 40; height: width; radius: width / 2
                                        color: sw.modelData.color
                                        Behavior on width { SpringAnimation { spring: 5; damping: 0.35 } }
                                        Icon { anchors.centerIn: parent; name: "check"; size: 16; visible: sw.on }
                                    }
                                    scale: swm.pressed ? 0.9 : swm.containsMouse ? 1.08 : 1
                                    Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.002 } }
                                    MouseArea { id: swm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("accentId", sw.modelData.id) }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: sw.modelData.label; color: sw.on ? "#FFFFFF" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                            }
                        }
                    }

                    SectionLabel { text: "Icon style" }
                    Row {
                        spacing: 12
                        Repeater {
                            model: [
                                { id: "minimal", label: "Minimal", sub: "Charcoal tiles, one accent detail" },
                                { id: "color",   label: "Colorful",  sub: "A bold gradient for every app" }
                            ]
                            Rectangle {
                                id: st
                                required property var modelData
                                readonly property bool on: Prefs.iconStyle === modelData.id
                                width: (body.width - 12) / 2
                                height: 112
                                radius: 18
                                color: stm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: on ? 2 : 1
                                border.color: on ? Theme.accent : Qt.rgba(1, 1, 1, 0.06)
                                scale: stm.pressed ? 0.97 : 1
                                Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.002 } }
                                Row {
                                    x: 16; y: 16
                                    spacing: 8
                                    Repeater {
                                        model: ["files", "browser", "terminal", "code", "store"]
                                        Image {
                                            required property string modelData
                                            width: 40; height: 40
                                            sourceSize: Qt.size(80, 80)
                                            source: st.modelData.id === "color" ? Qt.resolvedUrl("../assets/apps/" + modelData + ".svg")
                                                : Qt.resolvedUrl("../assets/apps-min/" + Prefs.accentId + "/" + modelData + ".svg")
                                        }
                                    }
                                }
                                Column {
                                    x: 18; y: 66
                                    Text { text: st.modelData.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text { text: st.modelData.sub; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                                }
                                MouseArea { id: stm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("iconStyle", st.modelData.id) }
                            }
                        }
                    }

                    SectionLabel { text: "Preview" }
                    Card {
                        width: parent.width
                        height: prevCol.implicitHeight + 36
                        Column {
                            id: prevCol
                            x: 18; y: 18
                            width: parent.width - 36
                            spacing: 14
                            Row {
                                spacing: 10
                                Rectangle { width: 110; height: 34; radius: 17; color: Theme.accent; Text { anchors.centerIn: parent; text: "Primary"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Bold } }
                                Rectangle { width: 110; height: 34; radius: 17; color: Theme.tint(0.22); Text { anchors.centerIn: parent; text: "Selected"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12 } }
                                Rectangle {
                                    width: 52; height: 30; radius: 15; color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle { x: 25; y: 3; width: 24; height: 24; radius: 12; color: "#FFFFFF" }
                                }
                            }
                            Rectangle {
                                width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle { width: parent.width * 0.62; height: 8; radius: 4; color: Theme.accent }
                            }
                            Text { text: "The accent color is used for buttons, selections, the active window border and the clock colon."; width: parent.width; wrapMode: Text.Wrap; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }
                }

                // ================= WI-FI =================
                Column {
                    visible: win.page === "wifi"
                    width: parent.width
                    spacing: 12

                    // không có Wi-Fi
                    Card {
                        visible: wifi.dev === ""
                        width: parent.width
                        height: 84
                        Rectangle {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 44; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Icon { anchors.centerIn: parent; name: Net.kind === "ethernet" ? "ethernet" : "wifi-off"; size: 20 }
                        }
                        Column {
                            x: 76; anchors.verticalCenter: parent.verticalCenter
                            Text { text: Net.kind === "ethernet" ? "Using a wired connection" : "This computer has no Wi-Fi"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { text: Net.kind === "ethernet" ? "Connected to the internet over a cable" : "Plug in a network cable or a USB Wi-Fi adapter to get online"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }

                    // bật / tắt
                    Card {
                        visible: wifi.dev !== ""
                        width: parent.width
                        height: 64
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            anchors.right: wsw.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: Net.wifiBlocked ? "Off" : wifi.current ? "Connected to " + wifi.current : "Not connected"
                            color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                        }
                        Toggle { id: wsw; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: !Net.wifiBlocked; onToggled: { Net.toggleWifi(); wifi.refresh(true); } }
                    }

                    Row {
                        visible: wifi.dev !== "" && !Net.wifiBlocked
                        width: parent.width
                        SectionLabel { text: "Nearby networks"; width: parent.width - 90 }
                        Text {
                            width: 90; horizontalAlignment: Text.AlignRight
                            text: "Rescan"; color: Qt.lighter(Theme.accent, 1.25); font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wifi.refresh(true) }
                        }
                    }
                    Text { visible: wifi.error !== "" && wifi.joining === ""; text: wifi.error; color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }

                    Card {
                        visible: wifi.dev !== "" && !Net.wifiBlocked
                        width: parent.width
                        height: netCol.implicitHeight + 8
                        Column {
                            id: netCol
                            y: 4
                            width: parent.width
                            Text { visible: wifi.nets.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "Looking for networks…"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                            Repeater {
                                model: wifi.nets
                                Rectangle {
                                    id: net
                                    required property var modelData
                                    readonly property bool asking: wifi.joining === modelData.name
                                    width: netCol.width
                                    height: asking ? 98 : 50
                                    color: nem.containsMouse && !asking ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                    radius: 14
                                    clip: true
                                    Behavior on height { SpringAnimation { spring: 4.5; damping: 0.35; epsilon: 0.2 } }
                                    MouseArea {
                                        id: nem
                                        width: parent.width; height: 50
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (net.modelData.cur) return;
                                            if (net.modelData.sec === "open" || net.modelData.saved) wifi.connect(net.modelData.name, "");
                                            else { wifi.joining = net.modelData.name; wifi.error = ""; pwIn.text = ""; pwIn.forceActiveFocus(); }
                                        }
                                    }
                                    Icon {
                                        x: 18; y: 16; size: 18
                                        name: net.modelData.q > 66 ? "wifi" : net.modelData.q > 33 ? "wifi-2" : "wifi-1"
                                        color: net.modelData.cur ? Theme.accent : "#FFFFFF"
                                    }
                                    Text { x: 50; y: 15; text: net.modelData.name; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: net.modelData.cur ? Font.DemiBold : Font.Normal }
                                    Row {
                                        anchors.right: parent.right; anchors.rightMargin: 16; y: 14
                                        spacing: 8
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: wifi.busy === net.modelData.name ? "Connecting…" : net.modelData.cur ? "Connected" : net.modelData.saved ? "Saved" : ""
                                            color: net.modelData.cur ? Qt.lighter(Theme.accent, 1.3) : "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                                        }
                                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 13; opacity: 0.6; visible: net.modelData.sec !== "open" }
                                        Rectangle {
                                            visible: net.modelData.cur || net.modelData.saved
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: dl.implicitWidth + 18; height: 24; radius: 12
                                            color: dlm.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                            Text { id: dl; anchors.centerIn: parent; text: net.modelData.cur ? "Disconnect" : "Forget"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11 }
                                            MouseArea {
                                                id: dlm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { Quickshell.execDetached(net.modelData.cur ? ["islet-wifi", "disconnect"] : ["islet-wifi", "forget", net.modelData.name]); wifi.refresh(false); }
                                            }
                                        }
                                    }
                                    // ô mật khẩu
                                    Rectangle {
                                        visible: net.asking
                                        x: 50; y: 52
                                        width: parent.width - 50 - 110
                                        height: 34; radius: 12
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1
                                        border.color: wifi.error ? Qt.rgba(1, 0.42, 0.42, 0.7) : pwIn.activeFocus ? Theme.tint(0.7) : Qt.rgba(1, 1, 1, 0.1)
                                        TextInput {
                                            id: pwIn
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: TextInput.Password
                                            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13
                                            Keys.onReturnPressed: wifi.connect(net.modelData.name, text)
                                            Keys.onEscapePressed: wifi.joining = ""
                                        }
                                        Text {
                                            visible: pwIn.text === ""
                                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                            text: wifi.error || "Wi-Fi password"; color: wifi.error ? "#FF8A8A" : "#636366"; font.family: Theme.font; font.pixelSize: 12
                                        }
                                    }
                                    Pill { visible: net.asking; x: parent.width - 100; y: 53; label: "Connect"; primary: true; onClicked: wifi.connect(net.modelData.name, pwIn.text) }
                                }
                            }
                        }
                    }
                }

                // ================= ÂM THANH =================
                Column {
                    visible: win.page === "sound"
                    width: parent.width
                    spacing: 12

                    Slider {
                        width: parent.width
                        title: "Output volume"
                        value: Audio.muted ? 0 : Math.min(1, Audio.volume)
                        available: Audio.sink !== null
                        fill: Theme.accent
                        onMoved: v => Audio.setVolume(v)
                    }
                    Card {
                        width: parent.width
                        height: 56
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Mute"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Audio.muted; onToggled: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted }
                    }

                    SectionLabel { text: "Output" }
                    DeviceList { nodes: win.sinks; current: Pipewire.defaultAudioSink; onPicked: n => Pipewire.preferredDefaultAudioSink = n; empty: "No speakers or headphones found" }

                    SectionLabel { text: "Input (microphone)" }
                    Slider {
                        width: parent.width
                        title: "Input volume"
                        visible: Pipewire.defaultAudioSource !== null
                        value: Math.min(1, Pipewire.defaultAudioSource?.audio?.volume ?? 0)
                        fill: Theme.accent
                        onMoved: v => { if (Pipewire.defaultAudioSource?.audio) Pipewire.defaultAudioSource.audio.volume = v; }
                    }
                    DeviceList { nodes: win.sources; current: Pipewire.defaultAudioSource; onPicked: n => Pipewire.preferredDefaultAudioSource = n; empty: "No microphone found" }
                }

                // ================= MÀN HÌNH =================
                Column {
                    visible: win.page === "display"
                    width: parent.width
                    spacing: 12

                    // hỏi giữ thay đổi
                    Rectangle {
                        visible: win.pendingRevert !== null
                        width: parent.width
                        height: 58
                        radius: 16
                        color: Theme.tint(0.18)
                        border.width: 1
                        border.color: Theme.tint(0.5)
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Keep these display settings? Reverting in " + win.revertLeft + "s"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Pill { label: "Revert"; onClicked: win.revertMonitor() }
                            Pill { label: "Keep"; primary: true; onClicked: win.keepMonitor() }
                        }
                    }

                    Slider {
                        width: parent.width
                        visible: Brightness.available
                        title: "Brightness"
                        value: Brightness.value
                        fill: Theme.amber
                        onMoved: v => Brightness.set(v)
                    }

                    Repeater {
                        model: win.monitors
                        Card {
                            id: mon
                            required property var modelData
                            readonly property string curMode: modelData.width + "x" + modelData.height + "@" + Math.round(modelData.refreshRate)
                            readonly property var modes: {
                                const seen = {}, out = [];
                                for (const m of (modelData.availableModes || [])) {
                                    const r = m.match(/^(\d+)x(\d+)@([\d.]+)/);
                                    if (!r) continue;
                                    const k = r[1] + "x" + r[2];
                                    if (seen[k]) continue;
                                    seen[k] = true;
                                    out.push({ label: r[1] + " × " + r[2], mode: k + "@" + Math.round(parseFloat(r[3])), w: +r[1] });
                                }
                                out.sort((a, b) => b.w - a.w);
                                const top = out.slice(0, 11);
                                const cur = out.find(o => o.mode.split("@")[0] === mon.curMode.split("@")[0]);
                                if (cur && top.indexOf(cur) < 0) top.push(cur);
                                return top;
                            }
                            width: parent.width
                            height: monCol.implicitHeight + 32
                            Column {
                                id: monCol
                                x: 18; y: 16
                                width: parent.width - 36
                                spacing: 12
                                Row {
                                    spacing: 12
                                    Rectangle {
                                        width: 54; height: 36; radius: 7
                                        color: "transparent"; border.width: 2; border.color: Theme.accent
                                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; width: 14; height: 5; color: Theme.accent }
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: (mon.modelData.make && mon.modelData.make !== "Unknown" ? mon.modelData.make + " " : "") + (mon.modelData.model || mon.modelData.name); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                        Text { text: mon.modelData.name + " · " + mon.modelData.width + "×" + mon.modelData.height + " · " + Math.round(mon.modelData.refreshRate) + " Hz · scale " + mon.modelData.scale; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                                    }
                                }
                                SectionLabel { text: "Resolution" }
                                Flow {
                                    width: parent.width
                                    spacing: 8
                                    Repeater {
                                        model: mon.modes
                                        Chip {
                                            required property var modelData
                                            label: modelData.label
                                            on: mon.curMode.split("@")[0] === modelData.mode.split("@")[0]
                                            onClicked: win.setMonitor(mon.modelData.name, { mode: modelData.mode })
                                        }
                                    }
                                }
                                SectionLabel { text: "Scale (make text and UI bigger or smaller)" }
                                Row {
                                    spacing: 8
                                    Repeater {
                                        model: [1, 1.25, 1.5, 1.75, 2]
                                        Chip {
                                            required property var modelData
                                            label: Math.round(modelData * 100) + "%"
                                            on: Math.abs(mon.modelData.scale - modelData) < 0.01
                                            onClicked: win.setMonitor(mon.modelData.name, { scale: modelData })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= GIỚI THIỆU =================
                Column {
                    visible: win.page === "about"
                    width: parent.width
                    spacing: 16

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Image {
                            id: logo
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 96; height: 96
                            sourceSize: Qt.size(192, 192)
                            source: Theme.appIcon("islet")
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                running: win.open && win.page === "about"
                                NumberAnimation { to: -4; duration: 1800; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InOutSine }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Islet"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Bold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.sys.os ?? ""; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                    }
                    Card {
                        width: parent.width
                        height: infoCol.implicitHeight + 8
                        Column {
                            id: infoCol
                            y: 4
                            width: parent.width
                            Repeater {
                                model: [
                                    ["Computer name", win.sys.host], ["Processor", (win.sys.cpu || "") + (win.sys.cores ? " · " + win.sys.cores + " threads" : "")],
                                    ["Memory", win.sys.ram], ["Graphics", win.sys.gpu], ["Disk", win.sys.disk],
                                    ["Linux kernel", win.sys.kernel], ["Hyprland", win.sys.hypr], ["Uptime", win.sys.up]
                                ]
                                Item {
                                    required property var modelData
                                    required property int index
                                    visible: (modelData[1] || "") !== ""
                                    width: infoCol.width
                                    height: 42
                                    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[0]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13 }
                                    Text {
                                        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 150; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                                        text: parent.modelData[1] || ""; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13
                                    }
                                    Rectangle { visible: parent.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= thành phần =================
    component SectionLabel: Text {
        color: "#8E8E93"
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
    component Hint: Text {
        width: parent ? parent.width : 300
        wrapMode: Text.Wrap
        color: "#636366"
        font.family: Theme.font
        font.pixelSize: 11
    }
    component Card: Rectangle {
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.05)
    }
    component Toggle: Rectangle {
        id: tg
        property bool checked: false
        signal toggled()
        width: 46; height: 28; radius: 14
        color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            y: 3; x: tg.checked ? tg.width - width - 3 : 3
            width: 22; height: 22; radius: 11
            color: "#FFFFFF"
            Behavior on x { SpringAnimation { spring: 5; damping: 0.36; epsilon: 0.1 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }
    component Pill: Rectangle {
        id: pb
        property string label: ""
        property bool primary: false
        signal clicked()
        width: pl.implicitWidth + 28
        height: 32
        radius: 16
        color: primary ? (pm2.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent) : (pm2.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09))
        Behavior on color { ColorAnimation { duration: 130 } }
        scale: pm2.pressed ? 0.94 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
        Text { id: pl; anchors.centerIn: parent; text: pb.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Bold }
        MouseArea { id: pm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }
    component Chip: Rectangle {
        id: ch
        property string label: ""
        property bool on: false
        signal clicked()
        width: cl.implicitWidth + 24
        height: 30
        radius: 15
        color: on ? Theme.accent : cm2.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: cm2.pressed ? 0.94 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
        Text { id: cl; anchors.centerIn: parent; text: ch.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: ch.on ? Font.DemiBold : Font.Normal }
        MouseArea { id: cm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }
    component DeviceList: Rectangle {
        id: dlst
        property var nodes: []
        property var current: null
        property string empty: ""
        signal picked(var node)
        width: parent ? parent.width : 300
        height: dcol.implicitHeight + 8
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.05)
        Column {
            id: dcol
            y: 4
            width: parent.width
            Text { visible: dlst.nodes.length === 0; leftPadding: 18; topPadding: 12; bottomPadding: 12; text: dlst.empty; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: dlst.nodes
                Rectangle {
                    id: dv
                    required property var modelData
                    readonly property bool on: dlst.current === modelData
                    width: dcol.width
                    height: 46
                    radius: 14
                    color: dvm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    Rectangle {
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18; radius: 9
                        color: "transparent"
                        border.width: 2
                        border.color: dv.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.3)
                        Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: dv.on }
                    }
                    Text {
                        x: 46; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60; elide: Text.ElideRight
                        text: dv.modelData.description || dv.modelData.nickname || dv.modelData.name
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: dv.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea { id: dvm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlst.picked(dv.modelData) }
                }
            }
        }
    }
}
