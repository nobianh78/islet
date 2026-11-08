import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"
import "../wallpaper"

// Chào mừng — chạy một lần sau khi cài: hình nền & màu, Wi-Fi, điện thoại, sao lưu, trình duyệt.
// Bỏ qua lúc nào cũng được; xong thì ghi Prefs.welcomeDone. Mở lại: `qs ipc call welcome open`.
PanelWindow {
    id: win

    implicitWidth: 820
    implicitHeight: 560
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool open: Ui.welcomeOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    property int step: 0
    readonly property var steps: [
        { id: "hello",   title: "Welcome to Islet",   sub: "" },
        { id: "look",    title: "Make it yours",      sub: "Pick a wallpaper and a colour — you can change these any time in Settings." },
        { id: "wifi",    title: "Get online",         sub: "Connect to Wi-Fi so Islet can get updates and look things up." },
        { id: "phone",   title: "Your phone",         sub: "Link your phone to share the clipboard, send files and see its notifications on the island." },
        { id: "backup",  title: "Keep your files safe", sub: "Plug in an external drive and Islet copies your Home folder, keeping a version for each day." },
        { id: "done",    title: "You're all set",     sub: "" }
    ]
    readonly property string sid: steps[step].id
    readonly property bool last: step === steps.length - 1

    onOpenChanged: if (open) { step = 0; panel.forceActiveFocus(); wifi.refresh(true); }
    onSidChanged: {
        if (sid === "wifi") wifi.refresh(true);
        if (sid === "phone") { phones.running = true; phoneTick.restart(); }
        if (sid === "backup") Backup.refresh();
    }

    function next() { if (!last) step++; else finish(); }
    function finish() { Prefs.set("welcomeDone", true); Ui.welcomeOpen = false; }

    // tên người dùng, để chào
    property string who: ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: win.who = text.trim().split(" ")[0] }
    }

    // ---------------- hình nền ----------------
    readonly property var wallNames: ({ islet: "Islet", lagoon: "Lagoon", dusk: "Dusk Isles", aurora: "Aurora", prism: "Prism", midnight: "Midnight" })
    property var walls: []
    Process {
        running: true
        command: ["sh", "-c", "ls /usr/share/islet/wallpapers/*.jpg /usr/share/islet/wallpapers/*.png 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: win.walls = text.split("\n").filter(x => x).map(p => ({ path: p, name: win.wallNames[p.split("/").pop().replace(/\.[^.]+$/, "")] ?? "" }))
        }
    }

    // ---------------- Wi-Fi ----------------
    QtObject {
        id: wifi
        property string dev: ""
        property var nets: []
        property string joining: ""
        property string busy: ""
        property string error: ""
        property string pw: ""
        function refresh(scan) { if (scan) Quickshell.execDetached(["islet-wifi", "scan"]); wst.running = true; rescan.restart(); }
        function connect(name, pass) { busy = name; error = ""; wcon.name = name; wcon.pw = pass || ""; wcon.running = true; }
    }
    Timer { id: rescan; interval: 2500; onTriggered: wlist.running = true }
    Timer { interval: 6000; repeat: true; running: win.open && win.sid === "wifi"; onTriggered: { wst.running = true; wlist.running = true; } }
    Process {
        id: wst
        command: ["islet-wifi", "status"]
        stdout: StdioCollector { onStreamFinished: wifi.dev = text.trim().split("\t")[0] || "" }
    }
    Process {
        id: wlist
        command: ["islet-wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: wifi.nets = text.split("\n").filter(x => x).map(l => {
                const p = l.split("\t");
                return { name: p[0], sec: p[1], q: parseInt(p[2]) || 0, cur: p[3] === "1", saved: p[4] === "1" };
            }).sort((a, b) => (b.cur - a.cur) || (b.q - a.q)).slice(0, 8)
        }
    }
    Process {
        id: wcon
        property string name: ""
        property string pw: ""
        command: ["islet-wifi", "connect", name]
        stdinEnabled: true
        onStarted: { write(pw + "\n"); stdinEnabled = false; }
        onExited: code => {
            stdinEnabled = true;
            if (code === 0) { wifi.joining = ""; wifi.error = ""; wifi.pw = ""; }
            else if (code === 3) { wifi.joining = wifi.busy; wifi.error = "Wrong password"; }
            else wifi.error = "Couldn't connect";
            wifi.busy = "";
            wst.running = true; wlist.running = true; Net.refresh();
        }
    }

    // ---------------- điện thoại ----------------
    property var devices: []
    property bool kdeInstalled: true
    Timer { id: phoneTick; interval: 3000; repeat: true; running: win.open && win.sid === "phone"; triggeredOnStart: true; onTriggered: phones.running = true }
    Process {
        id: phones
        command: ["islet-phone", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const d = JSON.parse(text || "[]"); win.kdeInstalled = d !== null; win.devices = d || []; }
                catch (e) { win.devices = []; }
            }
        }
    }
    Component { id: runner; Process {} }
    function phone(args) {
        const p = runner.createObject(win, { command: ["islet-phone"].concat(args) });
        p.exited.connect(() => { phones.running = true; p.destroy(); });
        p.running = true;
    }

    Glass {
        id: panel
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0.05, 0.05, 0.09, 0.92)
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.002 } }
        Keys.onEscapePressed: win.finish()

        // ---- nền: hình nền đang chọn, mờ ----
        Item {
            anchors.fill: parent
            clip: true
            opacity: 0.22
            Backdrop { anchors.fill: parent; animated: false }
        }

        // ---- nội dung ----
        Item {
            id: body
            anchors.fill: parent
            anchors.margins: 40
            anchors.bottomMargin: 88

            Column {
                id: header
                width: parent.width
                spacing: 6
                Row {
                    spacing: 14
                    visible: win.sid === "hello" || win.sid === "done"
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56; height: 56; sourceSize: Qt.size(112, 112)
                        source: Qt.resolvedUrl("../assets/brand/cat.svg")
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            readonly property string name: win.who.toLowerCase() === "islet" ? "" : win.who
                            text: win.sid === "done" ? (name ? "Enjoy Islet, " + name + "!" : "You're all set") : (name ? "Hello, " + name : "Welcome to Islet")
                            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 30; font.weight: Font.Bold
                        }
                        Text {
                            text: win.sid === "done" ? "Everything below is in Settings whenever you want to change it."
                                                     : "A few quick things and you're ready to go."
                            color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13
                        }
                    }
                }
                Text {
                    visible: win.sid !== "hello" && win.sid !== "done"
                    text: win.steps[win.step].title
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Bold
                }
                Text {
                    visible: win.sid !== "hello" && win.sid !== "done"
                    width: parent.width; wrapMode: Text.Wrap
                    text: win.steps[win.step].sub
                    color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13
                }
            }

            Item {
                id: pages
                anchors.top: header.bottom
                anchors.topMargin: 22
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom

                // ================= chào =================
                Column {
                    visible: win.sid === "hello"
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: [
                            ["image", "Your desktop, your way", "Wallpapers, colours, widgets and sticky notes."],
                            ["history", "Safe to tinker with", "A restore point before every update — go back any time."],
                            ["backup", "Your files, backed up", "Plug in a drive and Islet keeps a version of your Home folder for each day."],
                            ["phone", "Everything together", "Link your phone for shared clipboard, files and notifications."]
                        ]
                        Row {
                            required property var modelData
                            spacing: 14
                            Rectangle {
                                width: 42; height: 42; radius: 13; color: Theme.tint(0.22)
                                Icon { anchors.centerIn: parent; name: parent.parent.modelData[0]; size: 20 }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: parent.parent.modelData[1]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: parent.parent.modelData[2]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                            }
                        }
                    }
                }

                // ================= hình nền & màu =================
                Column {
                    visible: win.sid === "look"
                    width: parent.width
                    spacing: 16
                    Grid {
                        columns: 6
                        spacing: 10
                        Repeater {
                            model: win.walls
                            Rectangle {
                                required property var modelData
                                width: 112; height: 70; radius: 12
                                color: "transparent"
                                border.width: Prefs.wallpaper === modelData.path ? 2 : 0
                                border.color: Theme.accent
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 3
                                    radius: 9
                                    clip: true
                                    color: "#111118"
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + parent.parent.modelData.path
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(224, 140)
                                        asynchronous: true
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("wallpaper", parent.modelData.path) }
                            }
                        }
                    }
                    Column {
                        spacing: 8
                        Text { text: "Accent colour"; color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                        Row {
                            spacing: 10
                            Repeater {
                                model: Prefs.accents
                                Rectangle {
                                    required property var modelData
                                    width: 32; height: 32; radius: 16
                                    color: modelData.color
                                    border.width: Prefs.accentId === modelData.id ? 3 : 0
                                    border.color: Qt.rgba(1, 1, 1, 0.9)
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("accent", parent.modelData.id) }
                                }
                            }
                            Rectangle {
                                width: 32; height: 32; radius: 16
                                color: Prefs.autoAccent
                                border.width: Prefs.accentId === "auto" ? 3 : 1
                                border.color: Qt.rgba(1, 1, 1, Prefs.accentId === "auto" ? 0.9 : 0.25)
                                Icon { anchors.centerIn: parent; name: "sparkle"; size: 15 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("accent", "auto") }
                            }
                        }
                        Text { text: "The last one follows your wallpaper."; color: "#636366"; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }

                // ================= Wi-Fi =================
                Column {
                    visible: win.sid === "wifi"
                    width: parent.width
                    spacing: 10
                    Row {
                        spacing: 10
                        visible: Net.kind === "ethernet" || Net.kind === "wifi"
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: Net.icon; size: 18; color: "#34C77B" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Connected · " + Net.label; color: "#34C77B"; font.family: Theme.font; font.pixelSize: 13 }
                    }
                    Text {
                        visible: wifi.dev === ""
                        text: Net.kind === "ethernet" ? "You're on a cable — nothing to do here." : "This computer has no Wi-Fi adapter. Plug in a network cable to get online."
                        color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13
                    }
                    Rectangle {
                        visible: wifi.dev !== ""
                        width: parent.width; height: Math.min(nets.implicitHeight + 8, 250); radius: 16
                        color: Qt.rgba(1, 1, 1, 0.05)
                        clip: true
                        Column {
                            id: nets
                            y: 4; width: parent.width
                            Repeater {
                                model: wifi.nets
                                Item {
                                    id: nrow
                                    required property var modelData
                                    required property int index
                                    width: nets.width
                                    height: 44 + (wifi.joining === modelData.name ? 46 : 0)
                                    Rectangle { visible: nrow.index > 0; x: 14; width: parent.width - 28; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                                    Icon {
                                        x: 16; y: 14; size: 16
                                        name: nrow.modelData.q > 66 ? "wifi" : nrow.modelData.q > 33 ? "wifi-2" : "wifi-1"
                                        color: nrow.modelData.cur ? "#34C77B" : "#FFFFFF"
                                    }
                                    Text {
                                        x: 44; y: 14; width: parent.width - 160; elide: Text.ElideRight
                                        text: nrow.modelData.name
                                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13
                                    }
                                    Text {
                                        anchors.right: parent.right; anchors.rightMargin: 16; y: 15
                                        text: nrow.modelData.cur ? "Connected" : wifi.busy === nrow.modelData.name ? "Connecting…" : nrow.modelData.sec === "open" ? "Open" : ""
                                        color: nrow.modelData.cur ? "#34C77B" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                        height: 44
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !nrow.modelData.cur
                                        onClicked: {
                                            if (nrow.modelData.sec === "open" || nrow.modelData.saved) wifi.connect(nrow.modelData.name, "");
                                            else { wifi.joining = nrow.modelData.name; wifi.pw = ""; wifi.error = ""; pwIn.forceActiveFocus(); }
                                        }
                                    }
                                    // ô mật khẩu
                                    Row {
                                        visible: wifi.joining === nrow.modelData.name
                                        x: 44; y: 46
                                        spacing: 8
                                        Rectangle {
                                            width: 240; height: 36; radius: 11
                                            color: Qt.rgba(1, 1, 1, pwIn.activeFocus ? 0.12 : 0.06)
                                            border.width: 1; border.color: wifi.error ? "#FF5F57" : pwIn.activeFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                                            TextInput {
                                                id: pwIn
                                                x: 12; width: parent.width - 24
                                                anchors.verticalCenter: parent.verticalCenter
                                                echoMode: TextInput.Password
                                                color: "#FFFFFF"; selectionColor: Theme.accent
                                                font.family: Theme.font; font.pixelSize: 13
                                                onTextEdited: wifi.pw = text
                                                Keys.onReturnPressed: wifi.connect(nrow.modelData.name, wifi.pw)
                                            }
                                        }
                                        Btn { label: "Join"; primary: true; onClicked: wifi.connect(nrow.modelData.name, wifi.pw) }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: wifi.error; color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }
                                    }
                                }
                            }
                            Text {
                                visible: wifi.nets.length === 0
                                leftPadding: 16; topPadding: 12; bottomPadding: 12
                                text: "Looking for networks…"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                            }
                        }
                    }
                }

                // ================= điện thoại =================
                Column {
                    visible: win.sid === "phone"
                    width: parent.width
                    spacing: 12
                    Column {
                        visible: win.kdeInstalled
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: [
                                "Install KDE Connect on your phone — Android: Play Store or F-Droid · iPhone: App Store.",
                                "Put the phone on the same Wi-Fi as this computer.",
                                "Open the app, tap this computer and choose Pair — then accept it below."
                            ]
                            Row {
                                required property string modelData
                                required property int index
                                spacing: 10
                                Rectangle {
                                    width: 22; height: 22; radius: 11; color: Theme.tint(0.25)
                                    Text { anchors.centerIn: parent; text: parent.parent.index + 1; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 13 }
                            }
                        }
                    }
                    Text {
                        visible: !win.kdeInstalled
                        text: "Phone link needs KDE Connect — install it from the Store later, then open Settings › Phone."
                        color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13
                    }
                    Repeater {
                        model: win.devices
                        Rectangle {
                            id: dev
                            required property var modelData
                            width: pages.width; height: 58; radius: 14
                            color: Qt.rgba(1, 1, 1, 0.05)
                            Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "phone"; size: 20 }
                            Column {
                                x: 50; anchors.verticalCenter: parent.verticalCenter
                                Text { text: dev.modelData.name; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text {
                                    text: dev.modelData.incoming ? "Wants to pair with this computer"
                                        : dev.modelData.requested ? "Waiting for the phone to accept…"
                                        : dev.modelData.paired ? "Linked" : "Nearby · not linked"
                                    color: dev.modelData.paired ? "#34C77B" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                                }
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Btn { visible: dev.modelData.incoming; label: "Accept"; primary: true; onClicked: win.phone(["accept", dev.modelData.id]) }
                                Btn { visible: !dev.modelData.paired && !dev.modelData.incoming && !dev.modelData.requested; label: "Pair"; primary: true; onClicked: win.phone(["pair", dev.modelData.id]) }
                            }
                        }
                    }
                    Text {
                        visible: win.kdeInstalled && win.devices.length === 0
                        text: "Looking for phones…"; color: "#636366"; font.family: Theme.font; font.pixelSize: 12
                    }
                }

                // ================= sao lưu =================
                Column {
                    visible: win.sid === "backup"
                    width: parent.width
                    spacing: 12
                    Text {
                        visible: Backup.drives.length === 0
                        text: "No drive plugged in. You can set this up later in Settings › Storage & Backup — Islet will remind you when you plug one in."
                        width: parent.width; wrapMode: Text.Wrap
                        color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13
                    }
                    Repeater {
                        model: Backup.drives
                        Rectangle {
                            id: drv
                            required property var modelData
                            width: pages.width; height: 62; radius: 14
                            color: Prefs.backupDrive === modelData.uuid ? Theme.tint(0.18) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: Prefs.backupDrive === modelData.uuid ? 1 : 0
                            border.color: Theme.accent
                            Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "disk"; size: 20 }
                            Column {
                                x: 50; anchors.verticalCenter: parent.verticalCenter
                                Text { text: Backup.label(drv.modelData); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text {
                                    text: Math.round(drv.modelData.size / 1e9) + " GB · " + drv.modelData.fstype
                                        + (drv.modelData.history ? "" : " · keeps only the latest copy")
                                    color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                                }
                            }
                            Btn {
                                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                label: Prefs.backupDrive === drv.modelData.uuid ? "Chosen" : "Use this drive"
                                primary: Prefs.backupDrive === drv.modelData.uuid
                                onClicked: Backup.choose(drv.modelData)
                            }
                        }
                    }
                    Text {
                        text: "Islet skips caches and the Trash, and thins out old versions on its own."
                        color: "#636366"; font.family: Theme.font; font.pixelSize: 11
                    }
                }

                // ================= xong =================
                Column {
                    visible: win.sid === "done"
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: [
                            ["globe", "Sign in to your browser", "Bring your bookmarks, passwords and history over.", "Open Firefox"],
                            ["store", "Get your apps", "The Store has the usual ones, and anything else from the Arch repos.", "Open the Store"],
                            ["settings", "Everything else", "Displays, sound, keyboard, widgets, backups — all in Settings.", "Open Settings"]
                        ]
                        Rectangle {
                            id: card
                            required property var modelData
                            width: pages.width; height: 66; radius: 16
                            color: Qt.rgba(1, 1, 1, 0.05)
                            Rectangle {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: 40; height: 40; radius: 13; color: Theme.tint(0.22)
                                Icon { anchors.centerIn: parent; name: card.modelData[0]; size: 19 }
                            }
                            Column {
                                x: 68; anchors.verticalCenter: parent.verticalCenter
                                Text { text: card.modelData[1]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: card.modelData[2]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                            }
                            Btn {
                                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                label: card.modelData[3]
                                onClicked: {
                                    win.finish();
                                    if (card.modelData[0] === "globe") Quickshell.execDetached(["firefox", "https://accounts.firefox.com/signin"]);
                                    else if (card.modelData[0] === "store") Ui.openStore();
                                    else Ui.openSettings("");
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- chân: chấm bước + nút ----
        Row {
            x: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 34
            spacing: 7
            Repeater {
                model: win.steps.length
                Rectangle {
                    required property int index
                    width: index === win.step ? 20 : 7; height: 7; radius: 4
                    color: index === win.step ? Theme.accent : Qt.rgba(1, 1, 1, index < win.step ? 0.4 : 0.16)
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 28
            spacing: 10
            Btn { visible: win.step > 0 && !win.last; label: "Back"; onClicked: win.step-- }
            Btn { visible: !win.last; label: win.step === 0 ? "Skip" : "Skip the rest"; onClicked: win.finish() }
            Btn { label: win.last ? "Start using Islet" : win.step === 0 ? "Let's go" : "Next"; primary: true; onClicked: win.next() }
        }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool primary: false
        signal clicked()
        width: bl.implicitWidth + 36
        height: 38
        radius: 19
        color: primary ? (bm.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
                       : (bm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: bm.pressed ? 0.96 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
        Text { id: bl; anchors.centerIn: parent; text: b.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Bold }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
