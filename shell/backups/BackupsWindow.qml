import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"
import "../common"

// Time Machine — xem lại thư mục nhà như nó đã từng ở mỗi bản sao lưu, rồi lấy lại file.
//   trái: các bản (mới nhất trên cùng) · phải: thư mục của bản đang chọn
//   bấm đúp thư mục để vào · bấm đúp file / Space để xem nhanh · "Restore" chép về chỗ cũ
FloatingWindow {
    id: win

    title: "Time Machine"
    implicitWidth: 960
    implicitHeight: 620
    minimumSize: Qt.size(720, 460)
    color: Theme.window
    visible: false

    Connections {
        target: Ui
        function onBackupsOpenChanged() {
            if (Ui.backupsOpen) { win.visible = true; intro.restart(); Backup.refreshList(); win.pick(Backup.list[0]?.id ?? ""); }
            else win.visible = false;
        }
        function onBackupsRaiseRequested() { Windows.raiseShell("Time Machine"); }
    }
    onVisibleChanged: if (!visible && Ui.backupsOpen) Ui.backupsOpen = false
    function close() { Ui.backupsOpen = false; }
    function minimize() { if (!Windows.minimizeShell("Time Machine")) win.minimized = true; }
    function toggleMaximize() { win.maximized = !win.maximized; }

    property string version: ""           // bản đang xem
    property string path: ""              // thư mục trong bản (tương đối với thư mục nhà)
    property string root: ""              // đường dẫn thật của bản trên ổ
    property var items: []
    property bool loading: false
    property string selected: ""
    property string msg: ""
    function say(t) { msg = t; msgClear.restart(); }
    Timer { id: msgClear; interval: 6000; onTriggered: win.msg = "" }

    Connections {
        target: Backup
        function onListChanged() { if (win.visible && !Backup.list.some(v => v.id === win.version)) win.pick(Backup.list[0]?.id ?? ""); }
    }

    function pick(id) { version = id; selected = ""; open(path); }
    function open(rel) {
        if (!version || !Backup.mount) { items = []; return; }
        loading = true;
        lsProc.command = ["islet-backup", "ls", Backup.mount, version, rel];
        lsProc.running = true;
    }
    Process {
        id: lsProc
        stdout: StdioCollector {
            onStreamFinished: {
                win.loading = false;
                try {
                    const d = JSON.parse(text);
                    win.root = d.root; win.path = d.path; win.items = d.items || [];
                } catch (e) { win.items = []; win.path = ""; }
            }
        }
    }
    function rel(name) { return (path ? path + "/" : "") + name; }
    function full(name) { return root + "/" + rel(name); }
    function restore(name) {
        if (!name) return;
        const p = runner.createObject(win, { command: ["islet-backup", "restore", Backup.mount, version, rel(name)] });
        p.done.connect((code, out) => {
            win.say(code === 0 ? "Restored to " + out.trim().replace(Quickshell.env("HOME"), "~") : "Couldn't restore " + name);
            p.destroy();
        });
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: rp
            signal done(int code, string out)
            property string got: ""
            stdout: StdioCollector { onStreamFinished: rp.got = text }
            onExited: code => rp.done(code, rp.got)
        }
    }
    function look(name) { if (name) QuickLook.show(full(name)); }
    function enter(it) { if (it.dir) { selected = ""; open(rel(it.name)); } else look(it.name); }
    function up() { if (path) open(path.split("/").slice(0, -1).join("/")); }

    function human(b) {
        if (b < 1024) return b + " B";
        const u = ["KB", "MB", "GB", "TB"]; let i = -1;
        do { b /= 1024; i++; } while (b >= 1024 && i < u.length - 1);
        return (b >= 10 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function iconFor(it) {
        if (it.dir) return "file:///usr/share/icons/Islet/scalable/places/folder.svg";
        const ext = (it.name.split(".").pop() || "").toLowerCase();
        const m = { png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic", webp: "image-x-generic", gif: "image-x-generic", svg: "image-x-generic",
                    mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", mov: "video-x-generic",
                    mp3: "audio-x-generic", flac: "audio-x-generic", ogg: "audio-x-generic", wav: "audio-x-generic",
                    pdf: "application-pdf", zip: "package-x-generic", gz: "package-x-generic", xz: "package-x-generic", tar: "package-x-generic",
                    sh: "text-x-script", py: "text-x-script", js: "text-x-script" };
        return Quickshell.iconPath(m[ext] ?? "text-x-generic", true) || Quickshell.iconPath("text-x-generic", true);
    }
    function vlabel(v) {
        if (v.id === "Latest") return "Latest copy";
        return Backup.when(v.time * 1000);
    }

    Item {
        id: panel
        anchors.fill: parent
        focus: true
        transformOrigin: Item.Top
        Keys.onEscapePressed: win.close()
        Keys.onSpacePressed: win.look(win.selected)
        Keys.onReturnPressed: { const it = win.items.find(x => x.name === win.selected); if (it) win.enter(it); }
        Keys.onBackPressed: win.up()
        Keys.onPressed: e => { if (e.key === Qt.Key_Backspace) { win.up(); e.accepted = true; } }
        Keys.onUpPressed: { const i = win.items.findIndex(x => x.name === win.selected); if (i > 0) win.selected = win.items[i - 1].name; else if (i < 0 && win.items.length) win.selected = win.items[0].name; }
        Keys.onDownPressed: { const i = win.items.findIndex(x => x.name === win.selected); if (i < win.items.length - 1) win.selected = win.items[i + 1].name; }
        ParallelAnimation {
            id: intro
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; from: 0.98; to: 1; duration: 300; easing.type: Easing.OutCubic }
        }

        // ---------- thanh trên ----------
        Item {
            id: head
            width: parent.width; height: 76
            TitleDrag { anchors.fill: parent }
            WindowLights { x: 20; y: 19; onClose: win.close(); onMinimize: win.minimize(); onMaximize: win.toggleMaximize() }
            Row {
                x: 20; y: 38
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 9; color: Theme.tint(0.3)
                    TIcon { anchors.centerIn: parent; name: "history"; size: 17 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Time Machine"; color: Theme.label; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
                    Text {
                        text: !Backup.connected ? (Prefs.backupLabel || "Backup drive") + " is not connected"
                            : (Prefs.backupLabel || "Backup drive") + " · " + Backup.list.length + (Backup.list.length === 1 ? " version" : " versions")
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 20
                y: 40
                spacing: 8
                Btn { label: Backup.running ? "Backing up… " + Backup.pct + "%" : "Back up now"; enabled_: Backup.connected && !Backup.running; onClicked: Backup.backup() }
                Btn { label: "Restore"; primary: true; enabled_: win.selected !== ""; onClicked: win.restore(win.selected) }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.fg(0.06) }
        }

        // ---------- các bản sao lưu ----------
        Rectangle {
            id: side
            anchors.top: head.bottom; anchors.bottom: parent.bottom
            width: 230
            color: Theme.fg(0.025)
            Text { x: 20; y: 14; text: "VERSIONS"; color: Theme.faint; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1 }
            ListView {
                id: vlist
                anchors.fill: parent; anchors.topMargin: 36; anchors.margins: 10
                clip: true; spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: Backup.list
                delegate: Rectangle {
                    id: vrow
                    required property var modelData
                    required property int index
                    readonly property bool on: win.version === modelData.id
                    width: vlist.width; height: 46; radius: 12
                    color: on ? Theme.tint(0.22) : vm.containsMouse ? Theme.fg(0.06) : "transparent"
                    // dải thời gian bên trái, như Time Machine
                    Rectangle { x: 14; y: 0; width: 2; height: parent.height; color: Theme.fg(0.08); visible: vlist.count > 1 }
                    Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: vrow.on ? Theme.accent : "#48484A" }
                    Column {
                        x: 30; anchors.verticalCenter: parent.verticalCenter
                        Text { text: win.vlabel(vrow.modelData); color: Theme.label; font.family: Theme.font; font.pixelSize: 13; font.weight: vrow.on ? Font.DemiBold : Font.Normal }
                        Text { visible: vrow.index === 0; text: "Latest"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    MouseArea { id: vm; anchors.fill: parent; hoverEnabled: true; onClicked: { win.pick(vrow.modelData.id); panel.forceActiveFocus(); } }
                }
            }
        }

        // ---------- thư mục ----------
        Item {
            anchors.top: head.bottom; anchors.bottom: parent.bottom
            anchors.left: side.right; anchors.right: parent.right
            // đường dẫn
            Row {
                id: crumbs
                x: 18; y: 12; height: 28
                spacing: 4
                Repeater {
                    model: ["Home"].concat(win.path ? win.path.split("/") : [])
                    Row {
                        required property string modelData
                        required property int index
                        spacing: 4
                        Text { visible: parent.index > 0; anchors.verticalCenter: parent.verticalCenter; text: "›"; color: Theme.faint; font.family: Theme.font; font.pixelSize: 13 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData
                            color: cm.containsMouse ? Theme.label : Theme.subtle; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium
                            MouseArea {
                                id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: win.open(win.path.split("/").slice(0, parent.parent.index).join("/"))
                            }
                        }
                    }
                }
            }
            ListView {
                id: list
                anchors.fill: parent; anchors.topMargin: 46; anchors.margins: 12; anchors.bottomMargin: 30
                clip: true; spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: win.items
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool isSel: win.selected === modelData.name
                    width: list.width; height: 48; radius: 12
                    color: isSel ? Theme.tint(0.18) : rm.containsMouse ? Theme.fg(0.06) : "transparent"
                    MouseArea {
                        id: rm; anchors.fill: parent; hoverEnabled: true
                        onClicked: { win.selected = row.modelData.name; panel.forceActiveFocus(); }
                        onDoubleClicked: win.enter(row.modelData)
                    }
                    Image {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28; sourceSize: Qt.size(56, 56)
                        source: win.iconFor(row.modelData); asynchronous: true
                    }
                    Text {
                        x: 52; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 52 - 300
                        elide: Text.ElideMiddle; text: row.modelData.name
                        color: row.modelData.name.startsWith(".") ? Theme.muted : Theme.label; font.family: Theme.font; font.pixelSize: 13
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 150; anchors.verticalCenter: parent.verticalCenter
                        text: Backup.when(row.modelData.mtime * 1000); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 100; anchors.verticalCenter: parent.verticalCenter
                        visible: !row.modelData.dir
                        text: win.human(row.modelData.size); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                    }
                    Btn {
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        visible: rm.containsMouse || row.isSel
                        label: "Restore"
                        onClicked: win.restore(row.modelData.name)
                    }
                }
            }
            Column {
                visible: !win.loading && win.items.length === 0
                anchors.centerIn: list
                spacing: 8
                TIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "backup"; size: 46; opacity: 0.5 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !Backup.connected ? "Plug in " + (Prefs.backupLabel || "your backup drive") + " to see your backups"
                        : Backup.list.length === 0 ? "No backups on this drive yet" : "This folder is empty"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 13
                }
            }
            Text {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
                text: win.msg || "Double-click to open · Space — Quick Look · Restore puts a copy back where it was"
                color: win.msg ? "#34C77B" : Theme.faint; font.family: Theme.font; font.pixelSize: 11
            }
        }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool primary: false
        property bool enabled_: true
        signal clicked()
        width: bl.implicitWidth + 26
        height: 30
        radius: 15
        opacity: enabled_ ? 1 : 0.4
        color: primary ? (bm.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
             : (bm.containsMouse ? Theme.fg(0.16) : Theme.fg(0.08))
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: bm.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Text { id: bl; anchors.centerIn: parent; text: b.label; color: b.primary ? "#FFFFFF" : Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: bm; anchors.fill: parent; enabled: b.enabled_; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
