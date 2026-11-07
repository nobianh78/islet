import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../theme"
import "../services"
import "../common"
import "../controlcenter"
import "../wallpaper"
import "pages"

// App Cài đặt của Islet: Hình nền · Màu nhấn · Wi-Fi · Âm thanh · Màn hình · Giới thiệu.
// Mở: "Cài đặt" trên dock, nút bánh răng ở trung tâm điều khiển, hoặc `islet-ipc settings open`.
PanelWindow {
    id: win

    implicitWidth: 980
    implicitHeight: 680
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property bool open: Ui.settingsOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    readonly property string page: Ui.settingsPage
    // nhóm · trang (k = từ khoá cho ô tìm)
    readonly property var groups: ["Personalize", "Network & devices", "System", "Account"]
    readonly property var pages: [
        { id: "wallpaper", g: 0, label: "Wallpaper",        icon: "palette",   tint: "#B65CFF", k: "background image dynamic" },
        { id: "accent",    g: 0, label: "Appearance",       icon: "sparkle",   tint: "#FF6B97", k: "accent color icon style font text size" },
        { id: "island",    g: 0, label: "Island & Dock",    icon: "grid",      tint: "#8B7CFF", k: "dynamic island dock size autohide activities" },
        { id: "workspaces",g: 0, label: "Workspaces",       icon: "layers",    tint: "#5B8CFF", k: "desktops virtual animation" },
        { id: "access",    g: 0, label: "Accessibility",    icon: "user",      tint: "#2EC4B6", k: "zoom contrast motion cursor screen reader orca" },
        { id: "wifi",      g: 1, label: "Wi-Fi & Network",  icon: "wifi",      tint: "#3B8BFF", k: "internet hotspot vpn wireguard proxy ip qr" },
        { id: "bluetooth", g: 1, label: "Bluetooth",        icon: "bluetooth", tint: "#3B8BFF", k: "headphones pair" },
        { id: "sound",     g: 1, label: "Sound",            icon: "volume",    tint: "#FF5C7A", k: "volume app microphone system sounds" },
        { id: "display",   g: 1, label: "Displays",         icon: "sun",       tint: "#FFB547", k: "resolution scale monitor arrange rotate refresh brightness" },
        { id: "input",     g: 1, label: "Mouse & Touchpad", icon: "mouse",     tint: "#A78BFA", k: "gestures scroll tap" },
        { id: "keyboard",  g: 1, label: "Keyboard & Language", icon: "keyboard", tint: "#34C77B", k: "vietnamese telex vni typing input method layout repeat" },
        { id: "printers",  g: 1, label: "Printers",         icon: "document",  tint: "#7A8396", k: "print scanner cups" },
        { id: "power",     g: 2, label: "Power & Battery",  icon: "bolt",      tint: "#34C77B", k: "sleep lock idle lid battery saver night light charge" },
        { id: "notifs",    g: 2, label: "Notifications",    icon: "bell",      tint: "#FF5F57", k: "do not disturb apps lock screen" },
        { id: "apps",      g: 2, label: "Default Apps",     icon: "grid",      tint: "#5B8CFF", k: "browser video music image pdf open with" },
        { id: "startup",   g: 2, label: "Startup Apps",     icon: "play",      tint: "#FF9F43", k: "autostart login" },
        { id: "storage",   g: 2, label: "Storage",          icon: "disk",      tint: "#2EC4B6", k: "disk space clean cache trash" },
        { id: "snapshots", g: 2, label: "Snapshots & Backup", icon: "restart", tint: "#A78BFA", k: "rollback restore btrfs snapper backup" },
        { id: "datetime",  g: 2, label: "Date & Time",      icon: "timer",     tint: "#FFB547", k: "timezone clock 24h ntp" },
        { id: "privacy",   g: 2, label: "Privacy & Security", icon: "lock",    tint: "#FF6B97", k: "camera microphone firewall clipboard history" },
        { id: "updates",   g: 2, label: "Updates",          icon: "download",  tint: "#5B8CFF", k: "upgrade mirrors automatic" },
        { id: "account",   g: 3, label: "Users & Account",  icon: "user",      tint: "#34C77B", k: "password avatar name add user lock screen" },
        { id: "developer", g: 3, label: "Developer",        icon: "code",      tint: "#6D4AFF", k: "ssh docker hidden files projects" },
        { id: "about",     g: 3, label: "About",            icon: "islet",     tint: "#8B7CFF", k: "system info hostname disk health battery" }
    ]
    property string navQuery: ""
    function navMatch(pg) { const q = navQuery.trim().toLowerCase(); return !q || (pg.label + " " + pg.k).toLowerCase().indexOf(q) >= 0; }

    onOpenChanged: if (open) { panel.forceActiveFocus(); refreshPage(); }
    onPageChanged: if (open) refreshPage()
    function refreshPage() {
        if (page === "wallpaper") pics.running = true;
        if (page === "wifi") wifi.refresh(true);
        if (page === "display") mons.running = true;
        if (page === "about") about.running = true;
        if (page === "updates" && Date.now() - Updates.lastCheck > 10 * 60 * 1000) Updates.check();
        if (page === "account") gecos.running = true;
        if (page === "bluetooth" && win.bt && win.bt.enabled) win.bt.discovering = true;
        if (page !== "bluetooth" && win.bt && win.bt.discovering) win.bt.discovering = false;
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

    // Bluetooth
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDevices: (bt?.devices?.values ?? []).slice().sort((a, b) =>
        (b.connected - a.connected) || (b.paired - a.paired) || ((a.name || "").localeCompare(b.name || "")))
    function btIcon(d) {
        const i = (d.icon || "") + " " + (d.name || "").toLowerCase();
        if (/headset|headphone|audio|earbud|airpods|buds|speaker/.test(i)) return "headphones";
        if (/mouse/.test(i)) return "mouse";
        if (/keyboard/.test(i)) return "keyboard";
        if (/phone/.test(i)) return "phone";
        return "device";
    }

    // Tài khoản
    readonly property string userName: Quickshell.env("USER") || ""
    property string fullName: ""
    Process {
        id: gecos
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: win.fullName = text.trim() }
    }
    property string pwMsg: ""
    property bool pwOk: false
    property bool pwBusy: false
    function changePassword(oldPw, newPw, again) {
        pwOk = false;
        if (newPw.length < 4) { pwMsg = "The new password needs at least 4 characters"; return; }
        if (newPw !== again) { pwMsg = "The new passwords don't match"; return; }
        pwBusy = true; pwMsg = "";
        // xác minh mật khẩu hiện tại một lần qua PAM; đúng rồi mới đổi bằng sudo + chpasswd
        Auth.verify(oldPw, ok => {
            if (!ok) { win.pwBusy = false; win.pwMsg = "Current password is wrong"; return; }
            chpw.input = oldPw + "\n" + userName + ":" + newPw + "\n";
            chpw.running = true;
        });
    }
    Process {
        id: chpw
        property string input: ""
        // sudo đọc dòng 1 (mật khẩu hiện tại = xác minh đúng người), chpasswd đọc dòng 2
        command: ["sudo", "-S", "-p", "", "chpasswd"]
        stdinEnabled: true
        onStarted: { write(input); input = ""; stdinEnabled = false; }
        stderr: StdioCollector { id: chpwErr }
        onExited: code => {
            stdinEnabled = true;
            win.pwBusy = false;
            win.pwOk = code === 0;
            win.pwMsg = code === 0 ? "Password changed" : /incorrect|Sorry/i.test(chpwErr.text) ? "Current password is wrong" : "Couldn't change the password";
            if (code === 0) { oldPw.text = ""; newPw.text = ""; newPw2.text = ""; }
        }
    }

    property string upPwErr: ""
    Connections { target: Packages; function onPasswordRejected() { win.upPwErr = "Wrong password"; } }

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

            // ô tìm trang
            Rectangle {
                x: 12; y: 66
                width: parent.width - 24; height: 34; radius: 12
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: navIn.activeFocus ? Theme.tint(0.6) : Qt.rgba(1, 1, 1, 0.06)
                Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; opacity: 0.6 }
                TextInput {
                    id: navIn
                    x: 32; width: parent.width - 42; height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12
                    onTextChanged: win.navQuery = text
                    Keys.onReturnPressed: { const f = win.pages.find(pg => win.navMatch(pg)); if (f) Ui.settingsPage = f.id; }
                    Keys.onEscapePressed: text = ""
                }
                Text { visible: navIn.text === ""; x: 32; anchors.verticalCenter: parent.verticalCenter; text: "Find a setting"; color: "#636366"; font.family: Theme.font; font.pixelSize: 12 }
            }

            Flickable {
                x: 12; y: 110
                width: parent.width - 24
                height: parent.height - y - 10
                contentHeight: navCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: navCol
                    width: parent.width
                    spacing: 1
                    Repeater {
                        model: win.groups
                        Column {
                            id: grp
                            required property string modelData
                            required property int index
                            readonly property var items: win.pages.filter(pg => pg.g === grp.index && win.navMatch(pg))
                            visible: items.length > 0
                            width: navCol.width
                            spacing: 1
                            Text {
                                leftPadding: 10; topPadding: grp.index ? 10 : 0; bottomPadding: 4
                                text: grp.modelData.toUpperCase()
                                color: "#636366"; font.family: Theme.font; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.6
                            }
                            Repeater {
                                model: grp.items
                                Rectangle {
                                    id: nav
                                    required property var modelData
                                    readonly property bool on: win.page === modelData.id
                                    width: grp.width
                                    height: 32
                                    radius: 11
                                    color: on ? Theme.tint(0.22) : nm.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Rectangle {
                                        x: 8; anchors.verticalCenter: parent.verticalCenter
                                        width: 24; height: 24; radius: 7
                                        color: Prefs.iconStyle === "color" ? nav.modelData.tint : nav.on ? Theme.accent : Qt.rgba(1, 1, 1, 0.09)
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                        Icon { anchors.centerIn: parent; name: nav.modelData.icon; size: 14 }
                                    }
                                    Text { x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight; text: nav.modelData.label; color: nav.on ? "#FFFFFF" : "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12; font.weight: nav.on ? Font.DemiBold : Font.Normal }
                                    MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.settingsPage = nav.modelData.id }
                                }
                            }
                        }
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

        // ---------- hỏi mật khẩu quản trị (Admin.askPassword) ----------
        Rectangle {
            id: adminSheet
            anchors.fill: parent
            radius: 28
            z: 20
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: opacity > 0.01
            opacity: Admin.askPassword ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            onVisibleChanged: if (Admin.askPassword) { adminPw.text = ""; adminPw.focusField(); }
            MouseArea { anchors.fill: parent; onClicked: {} }
            Rectangle {
                anchors.centerIn: parent
                width: 380; height: 190; radius: 22
                color: Qt.rgba(0.1, 0.1, 0.14, 0.98)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                scale: Admin.askPassword ? 1 : 0.92
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.32 } }
                Column {
                    x: 22; y: 20
                    width: parent.width - 44
                    spacing: 10
                    Row {
                        spacing: 10
                        Icon { name: "lock"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Administrator password"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { width: parent.width; wrapMode: Text.Wrap; text: "Enter your password to change this system setting."; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                    PwField { id: adminPw; width: parent.width; hint: "Password"; onAccepted: Admin.submit(text) }
                    Row {
                        spacing: 8
                        Pill { label: Auth.busy ? "Checking…" : "Continue"; primary: true; onClicked: Admin.submit(adminPw.text) }
                        Pill { label: "Cancel"; onClicked: Admin.cancel() }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Admin.error; color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }
                    }
                }
            }
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

                WallpaperExtras { visible: win.page === "wallpaper"; width: parent.width; onFetched: pics.running = true }

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

                AppearanceExtras { visible: win.page === "accent"; width: parent.width }

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

                NetworkExtras { visible: win.page === "wifi"; width: parent.width; ssid: wifi.current }

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

                SoundExtras { visible: win.page === "sound"; width: parent.width }

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

                DisplayExtras { visible: win.page === "display"; width: parent.width; monitors: win.monitors; onApply: (name, patch) => win.setMonitor(name, patch) }

                // ================= BLUETOOTH =================
                Column {
                    visible: win.page === "bluetooth"
                    width: parent.width
                    spacing: 12

                    Card {
                        visible: !win.bt
                        width: parent.width
                        height: 84
                        Rectangle {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 44; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Icon { anchors.centerIn: parent; name: "bluetooth"; size: 20; opacity: 0.6 }
                        }
                        Column {
                            x: 76; anchors.verticalCenter: parent.verticalCenter
                            Text { text: "No Bluetooth adapter"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { text: "This computer has no Bluetooth, or it is turned off in the firmware"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }

                    Card {
                        visible: !!win.bt
                        width: parent.width
                        height: 64
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Bluetooth"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            anchors.right: btsw.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: !win.bt ? "" : !win.bt.enabled ? "Off" : win.bt.discovering ? "Searching…" : "On · " + (win.bt.name || "")
                            color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                        }
                        Toggle {
                            id: btsw
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            checked: win.bt?.enabled ?? false
                            onToggled: { if (win.bt) { win.bt.enabled = !win.bt.enabled; if (win.bt.enabled) btScan.restart(); } }
                        }
                        Timer { id: btScan; interval: 1200; onTriggered: if (win.bt && win.bt.enabled) win.bt.discovering = true }
                    }

                    Row {
                        visible: !!win.bt && win.bt.enabled
                        width: parent.width
                        SectionLabel { text: "Devices"; width: parent.width - 90 }
                        Text {
                            width: 90; horizontalAlignment: Text.AlignRight
                            text: win.bt?.discovering ? "Stop" : "Search"
                            color: Qt.lighter(Theme.accent, 1.25); font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (win.bt) win.bt.discovering = !win.bt.discovering }
                        }
                    }

                    Card {
                        visible: !!win.bt && win.bt.enabled
                        width: parent.width
                        height: btCol.implicitHeight + 8
                        Column {
                            id: btCol
                            y: 4
                            width: parent.width
                            Text {
                                visible: win.btDevices.length === 0
                                leftPadding: 18; topPadding: 14; bottomPadding: 14
                                text: "Looking for devices… put your headphones or mouse in pairing mode"
                                color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                            }
                            Repeater {
                                model: win.btDevices
                                Rectangle {
                                    id: dev
                                    required property var modelData
                                    readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                                    width: btCol.width
                                    height: 54
                                    radius: 14
                                    color: dm2.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                    MouseArea { id: dm2; anchors.fill: parent; hoverEnabled: true }
                                    Rectangle {
                                        x: 14; anchors.verticalCenter: parent.verticalCenter
                                        width: 34; height: 34; radius: 11
                                        color: dev.modelData.connected ? Theme.tint(0.3) : Qt.rgba(1, 1, 1, 0.08)
                                        Icon { anchors.centerIn: parent; name: win.btIcon(dev.modelData); size: 17 }
                                    }
                                    Column {
                                        x: 60; anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 60 - btAct.width - 24
                                        Text { width: parent.width; elide: Text.ElideRight; text: dev.modelData.name || dev.modelData.address; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: dev.modelData.connected ? Font.DemiBold : Font.Normal }
                                        Text {
                                            text: dev.modelData.pairing ? "Pairing…"
                                                : dev.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                                                : dev.modelData.connected ? "Connected" + (dev.modelData.batteryAvailable ? " · battery " + Math.round(dev.modelData.battery * 100) + "%" : "")
                                                : dev.modelData.paired ? "Paired" : "Not paired"
                                            color: dev.modelData.connected ? Qt.lighter(Theme.accent, 1.3) : "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                                        }
                                    }
                                    Row {
                                        id: btAct
                                        anchors.right: parent.right; anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Pill {
                                            visible: !dev.busy
                                            label: dev.modelData.connected ? "Disconnect" : dev.modelData.paired ? "Connect" : "Pair"
                                            primary: !dev.modelData.connected
                                            onClicked: {
                                                const d = dev.modelData;
                                                if (d.connected) d.disconnect();
                                                else if (d.paired) d.connect();
                                                else { d.trusted = true; d.pair(); }
                                            }
                                        }
                                        Pill {
                                            visible: dev.modelData.paired && !dev.busy && dm2.containsMouse
                                            label: "Forget"
                                            onClicked: dev.modelData.forget()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= NGUỒN ĐIỆN =================
                Column {
                    visible: win.page === "power"
                    width: parent.width
                    spacing: 12

                    // pin
                    Card {
                        visible: Power.present
                        width: parent.width
                        height: 72
                        Rectangle {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            width: 56; height: 26; radius: 7
                            color: "transparent"; border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.6)
                            Rectangle {
                                x: 3; y: 3; height: parent.height - 6; radius: 4
                                width: (parent.width - 6) * Math.max(0.04, Power.percent / 100)
                                color: Power.percent <= 20 && !Power.charging ? "#FF5F57" : Power.charging ? "#34C77B" : "#FFFFFF"
                            }
                            Rectangle { anchors.left: parent.right; anchors.leftMargin: 1; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 10; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.6) }
                        }
                        Column {
                            x: 92; anchors.verticalCenter: parent.verticalCenter
                            Text { text: Math.round(Power.percent) + "%" + (Power.charging ? " · charging" : " · on battery"); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text {
                                readonly property real secs: Power.charging ? (UPower.displayDevice?.timeToFull ?? 0) : (UPower.displayDevice?.timeToEmpty ?? 0)
                                visible: secs > 0
                                text: Math.floor(secs / 3600) + " h " + Math.round(secs % 3600 / 60) + " min " + (Power.charging ? "until full" : "left")
                                color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }

                    SectionLabel { text: "Power mode" }
                    Row {
                        spacing: 10
                        Repeater {
                            model: [
                                { p: PowerProfile.PowerSaver, label: "Battery saver", sub: "Longer battery life", icon: "sleep" },
                                { p: PowerProfile.Balanced, label: "Balanced", sub: "Good for most things", icon: "sliders" },
                                { p: PowerProfile.Performance, label: "Performance", sub: "Fastest, uses more power", icon: "bolt" }
                            ]
                            Rectangle {
                                id: pmode
                                required property var modelData
                                readonly property bool on: PowerProfiles.profile === modelData.p
                                readonly property bool avail: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                width: (body.width - 20) / 3
                                height: 78; radius: 18
                                opacity: avail ? 1 : 0.4
                                color: on ? Theme.tint(0.22) : pmm.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: on ? 2 : 1
                                border.color: on ? Theme.accent : Qt.rgba(1, 1, 1, 0.06)
                                Icon { x: 14; y: 14; name: pmode.modelData.icon; size: 18; color: pmode.on ? Qt.lighter(Theme.accent, 1.3) : "#FFFFFF" }
                                Column {
                                    x: 14; y: 38
                                    Text { text: pmode.modelData.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text { text: pmode.modelData.sub; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 10 }
                                }
                                MouseArea { id: pmm; anchors.fill: parent; enabled: pmode.avail; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfiles.profile = pmode.modelData.p }
                            }
                        }
                    }
                    Card {
                        visible: Power.present
                        width: parent.width; height: 56
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Turn on Battery saver automatically at 20%"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Prefs.autoSaver; onToggled: Prefs.set("autoSaver", !Prefs.autoSaver) }
                    }

                    SectionLabel { text: "When the computer is idle" }
                    Card {
                        width: parent.width
                        height: idleCol.implicitHeight + 24
                        Column {
                            id: idleCol
                            x: 18; y: 12
                            width: parent.width - 36
                            spacing: 2
                            Repeater {
                                model: [
                                    { k: "dimAfter", label: "Dim the screen after", opts: [0, 60, 120, 300] },
                                    { k: "lockAfter", label: "Lock after", opts: [0, 120, 300, 600, 900] },
                                    { k: "screenOffAfter", label: "Turn off the screen after", opts: [0, 180, 360, 600, 1200] },
                                    { k: "sleepAfterBattery", label: "Sleep on battery after", opts: [0, 300, 600, 900, 1800] },
                                    { k: "sleepAfterAC", label: "Sleep when plugged in after", opts: [0, 900, 1800, 3600] }
                                ]
                                Item {
                                    id: irow
                                    required property var modelData
                                    width: idleCol.width
                                    height: 44
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: irow.modelData.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        Repeater {
                                            model: irow.modelData.opts
                                            Chip {
                                                required property int modelData
                                                label: modelData === 0 ? "Never" : modelData < 3600 ? (modelData / 60) + " min" : (modelData / 3600) + " h"
                                                on: Prefs[irow.modelData.k] === modelData
                                                onClicked: Prefs.set(irow.modelData.k, modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Card {
                        width: parent.width; height: 56
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "When I close the lid"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                model: [{ v: "sleep", l: "Sleep" }, { v: "lock", l: "Lock only" }, { v: "nothing", l: "Do nothing" }]
                                Chip { required property var modelData; label: modelData.l; on: Prefs.lidAction === modelData.v; onClicked: Prefs.set("lidAction", modelData.v) }
                            }
                        }
                    }
                    Hint { text: "Videos and calls keep the screen awake. The screen always locks before the computer sleeps." }

                    SectionLabel { text: "Night Light" }
                    Card {
                        width: parent.width
                        height: nlCol.implicitHeight + 32
                        Column {
                            id: nlCol
                            x: 18; y: 16
                            width: parent.width - 36
                            spacing: 14
                            Row {
                                spacing: 8
                                Repeater {
                                    model: [{ v: "off", l: "Off" }, { v: "schedule", l: "Sunset to sunrise" }, { v: "on", l: "On now" }]
                                    Chip { required property var modelData; label: modelData.l; on: Prefs.nightMode === modelData.v; onClicked: Prefs.set("nightMode", modelData.v) }
                                }
                            }
                            Row {
                                visible: Prefs.nightMode === "schedule"
                                spacing: 10
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "From"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                                Repeater {
                                    model: ["18:00", "19:00", "20:00", "21:00"]
                                    Chip { required property string modelData; label: modelData; on: Prefs.nightFrom === modelData; onClicked: Prefs.set("nightFrom", modelData) }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "to"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                                Repeater {
                                    model: ["05:30", "06:30", "07:30"]
                                    Chip { required property string modelData; label: modelData; on: Prefs.nightTo === modelData; onClicked: Prefs.set("nightTo", modelData) }
                                }
                            }
                            Slider {
                                width: parent.width
                                title: "Warmth"
                                label: v => Math.round(6500 - v * 3500) + " K"
                                value: (6500 - Prefs.nightTemp) / 3500
                                fill: "#FF9F43"
                                onMoved: v => Prefs.set("nightTemp", Math.round(6500 - v * 3500))
                            }
                            Text {
                                text: NightLight.active ? "On now · " + NightLight.current + " K" : "Off now"
                                color: NightLight.active ? "#FFB547" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }
                }

                PowerExtras { visible: win.page === "power" && Power.present; width: parent.width }

                // ================= CHUỘT & TOUCHPAD =================
                Column {
                    visible: win.page === "input"
                    width: parent.width
                    spacing: 12
                    SectionLabel { text: "Touchpad" }
                    Card {
                        width: parent.width
                        height: tpCol.implicitHeight + 8
                        Column {
                            id: tpCol
                            y: 4
                            width: parent.width
                            Repeater {
                                model: [
                                    { k: "naturalScroll", t: "Natural scrolling", s: "Content moves with your fingers" },
                                    { k: "tapToClick", t: "Tap to click", s: "Tap the touchpad instead of pressing it" },
                                    { k: "disableWhileTyping", t: "Ignore touchpad while typing", s: "Stops accidental clicks with your palm" }
                                ]
                                Item {
                                    required property var modelData
                                    required property int index
                                    width: tpCol.width; height: 58
                                    Rectangle { visible: parent.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                                    Column {
                                        x: 18; anchors.verticalCenter: parent.verticalCenter
                                        Text { text: parent.parent.modelData.t; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                                        Text { text: parent.parent.modelData.s; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                                    }
                                    Toggle {
                                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                        checked: Prefs[parent.modelData.k]
                                        onToggled: Prefs.set(parent.modelData.k, !Prefs[parent.modelData.k])
                                    }
                                }
                            }
                        }
                    }
                    Slider {
                        width: parent.width
                        title: "Pointer speed"
                        value: (Prefs.pointerSpeed + 1) / 2
                        fill: Theme.accent
                        onMoved: v => Prefs.set("pointerSpeed", Math.round((v * 2 - 1) * 20) / 20)
                    }
                    Slider {
                        width: parent.width
                        title: "Scrolling speed"
                        value: (Prefs.scrollSpeed - 0.25) / 1.75
                        fill: Theme.accent
                        onMoved: v => Prefs.set("scrollSpeed", Math.round((0.25 + v * 1.75) * 20) / 20)
                    }
                    SectionLabel { text: "Gestures" }
                    Card {
                        width: parent.width
                        height: gCol.implicitHeight + 24
                        Column {
                            id: gCol
                            x: 18; y: 12
                            width: parent.width - 36
                            spacing: 0
                            Repeater {
                                model: [
                                    ["3 fingers left / right", "Switch desktop"],
                                    ["3 fingers up · pinch 4 fingers", "Overview of all windows"],
                                    ["3 fingers down", "Close Overview"],
                                    ["Super + Tab", "Overview from the keyboard"]
                                ]
                                Item {
                                    required property var modelData
                                    width: gCol.width; height: 38
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[0]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                                }
                            }
                        }
                    }
                }

                // ================= TÀI KHOẢN =================
                Column {
                    visible: win.page === "account"
                    width: parent.width
                    spacing: 12

                    Card {
                        width: parent.width
                        height: 88
                        Image {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            width: 56; height: 56
                            sourceSize: Qt.size(112, 112)
                            source: Qt.resolvedUrl("../assets/brand/cat.svg")
                        }
                        Column {
                            x: 88; anchors.verticalCenter: parent.verticalCenter
                            Text { text: win.fullName || win.userName; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { text: win.userName + " · administrator"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }

                    SectionLabel { text: "Sign-in" }
                    Card {
                        width: parent.width
                        height: 64
                        Column {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Lock screen at startup"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                            Text { text: "Ask for your password every time the computer starts"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                        }
                        Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Prefs.lockOnBoot; onToggled: Prefs.set("lockOnBoot", !Prefs.lockOnBoot) }
                    }

                    SectionLabel { text: "Change password" }
                    Card {
                        width: parent.width
                        height: pwCol.implicitHeight + 32
                        Column {
                            id: pwCol
                            x: 18; y: 16
                            width: parent.width - 36
                            spacing: 10
                            PwField { id: oldPw; width: parent.width; hint: "Current password" }
                            PwField { id: newPw; width: parent.width; hint: "New password" }
                            PwField { id: newPw2; width: parent.width; hint: "Confirm new password"; onAccepted: win.changePassword(oldPw.text, newPw.text, newPw2.text) }
                            Row {
                                spacing: 12
                                Pill { label: win.pwBusy ? "Changing…" : "Change password"; primary: true; onClicked: if (!win.pwBusy) win.changePassword(oldPw.text, newPw.text, newPw2.text) }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: win.pwMsg
                                    color: win.pwOk ? "#34C77B" : "#FF8A8A"
                                    font.family: Theme.font; font.pixelSize: 12
                                }
                            }
                        }
                    }
                }

                AccountExtras { visible: win.page === "account"; width: parent.width; fullName: win.fullName }

                // ================= CẬP NHẬT =================
                Column {
                    visible: win.page === "updates"
                    width: parent.width
                    spacing: 12

                    Card {
                        width: parent.width
                        height: upCol.implicitHeight + 36
                        Column {
                            id: upCol
                            x: 18; y: 18
                            width: parent.width - 36
                            spacing: 12
                            Row {
                                width: parent.width
                                spacing: 14
                                Rectangle {
                                    width: 46; height: 46; radius: 15
                                    color: Updates.count > 0 || Updates.running ? Theme.tint(0.25) : Qt.rgba(0.2, 0.78, 0.48, 0.2)
                                    Icon {
                                        anchors.centerIn: parent
                                        name: Updates.count > 0 || Updates.running ? "download" : "check"
                                        size: 22
                                        color: Updates.count > 0 || Updates.running ? Qt.lighter(Theme.accent, 1.3) : "#34C77B"
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 60 - upBtn.width - 14
                                    Text {
                                        text: Updates.running ? "Updating…"
                                            : Updates.checking ? "Checking for updates…"
                                            : Updates.count > 0 ? Updates.count + (Updates.count === 1 ? " update available" : " updates available")
                                            : "Islet is up to date"
                                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: Updates.running ? Packages.stepText
                                            : Updates.error ? Updates.error
                                            : Updates.lastCheck ? "Last checked " + Qt.formatTime(new Date(Updates.lastCheck), "HH:mm") : "Not checked yet"
                                        color: Updates.error ? "#FF8A8A" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                                    }
                                }
                                Pill {
                                    id: upBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !Updates.running
                                    label: Updates.count > 0 ? "Update now" : Updates.checking ? "Checking…" : "Check now"
                                    primary: Updates.count > 0
                                    onClicked: Updates.count > 0 ? Updates.upgrade() : Updates.check()
                                }
                            }
                            // thanh tiến trình
                            Rectangle {
                                visible: Updates.running
                                width: parent.width; height: 8; radius: 4
                                color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle {
                                    height: parent.height; radius: 4
                                    width: Math.max(8, parent.width * Packages.pct / 100)
                                    color: Theme.accent
                                    Behavior on width { SpringAnimation { spring: 3; damping: 0.5 } }
                                }
                            }
                            // mật khẩu (sudo cần mật khẩu)
                            Row {
                                visible: Packages.askPassword && Updates.running
                                spacing: 10
                                PwField { id: upPw; width: 260; hint: "Your password"; onAccepted: { win.upPwErr = ""; Packages.submitPassword(text); } }
                                Pill { label: "Continue"; primary: true; onClicked: { win.upPwErr = ""; Packages.submitPassword(upPw.text); } }
                                Pill { label: "Cancel"; onClicked: { win.upPwErr = ""; Packages.cancelPassword(); } }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: win.upPwErr; color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }
                            }
                        }
                    }

                    // khởi động lại sau khi cập nhật nhân / systemd / driver
                    Rectangle {
                        visible: Updates.needsReboot && !Updates.running
                        width: parent.width; height: 58; radius: 16
                        color: Theme.tint(0.16)
                        border.width: 1; border.color: Theme.tint(0.45)
                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Restart to finish installing the new system core"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Pill { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; label: "Restart"; primary: true; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
                    }

                    SectionLabel { text: "What's new"; visible: Updates.count > 0 }
                    Card {
                        visible: Updates.count > 0
                        width: parent.width
                        height: Math.min(upList.implicitHeight, 300) + 8
                        clip: true
                        Flickable {
                            y: 4
                            width: parent.width
                            height: parent.height - 8
                            contentHeight: upList.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            Column {
                                id: upList
                                width: parent.width
                                Repeater {
                                    model: Updates.list
                                    Item {
                                        required property var modelData
                                        width: upList.width
                                        height: 38
                                        Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                                        Rectangle {
                                            visible: parent.modelData.aur
                                            x: 18 + nameW.implicitWidth + 8; anchors.verticalCenter: parent.verticalCenter
                                            width: 34; height: 18; radius: 9
                                            color: Qt.rgba(1, 0.71, 0.28, 0.18)
                                            Text { anchors.centerIn: parent; text: "AUR"; color: "#FFB547"; font.family: Theme.font; font.pixelSize: 9; font.weight: Font.Bold }
                                            Text { id: nameW; visible: false; text: parent.parent.modelData.name; font.family: Theme.font; font.pixelSize: 13 }
                                        }
                                        Text {
                                            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                                            text: parent.modelData.from + "  →  " + parent.modelData.to
                                            color: "#8E8E93"; font.family: Theme.mono; font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Hint { text: "Islet checks for updates every few hours and lets you know on the island. Updating needs an internet connection." }
                }

                UpdatesExtras { visible: win.page === "updates"; width: parent.width }

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
                AboutExtras { visible: win.page === "about"; width: parent.width; sys: win.sys }

                // ---- các trang mới (settings/pages) ----
                IslandPage { visible: win.page === "island" }
                WorkspacesPage { visible: win.page === "workspaces" }
                AccessibilityPage { visible: win.page === "access" }
                KeyboardPage { visible: win.page === "keyboard" }
                PrintersPage { visible: win.page === "printers" }
                NotificationsPage { visible: win.page === "notifs" }
                DefaultAppsPage { visible: win.page === "apps" }
                StartupPage { visible: win.page === "startup" }
                StoragePage { visible: win.page === "storage" }
                SnapshotsPage { visible: win.page === "snapshots" }
                DateTimePage { visible: win.page === "datetime" }
                PrivacyPage { visible: win.page === "privacy" }
                DeveloperPage { visible: win.page === "developer" }
            }
        }
    }

}
