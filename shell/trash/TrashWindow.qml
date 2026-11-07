import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Cửa sổ Thùng rác (bấm thùng rác trên dock): xem những gì đã xoá, khôi phục về chỗ cũ,
// xoá vĩnh viễn từng mục, hoặc dọn sạch. Thả file vào cửa sổ này cũng là bỏ vào thùng rác.
FloatingWindow {
    id: win

    title: "Trash"
    implicitWidth: 860
    implicitHeight: 580
    minimumSize: Qt.size(640, 420)
    color: "#0D0D15"
    visible: false

    Connections {
        target: Ui
        function onTrashOpenChanged() {
            if (Ui.trashOpen) { win.visible = true; intro.restart(); Trash.watchers++; Trash.load(); win.confirmEmpty = false; win.armed = ""; }
            else { if (win.visible) Trash.watchers = Math.max(0, Trash.watchers - 1); win.visible = false; }
        }
        function onTrashRaiseRequested() { Windows.raiseShell("Trash"); }
        function onTrashEmptyAsked() { if (Trash.count > 0) win.confirmEmpty = true; }
    }
    onVisibleChanged: if (!visible && Ui.trashOpen) Ui.trashOpen = false
    function close() { Ui.trashOpen = false; }
    function minimize() { if (!Windows.minimizeShell("Trash")) win.minimized = true; }
    function toggleMaximize() { win.maximized = !win.maximized; }

    property bool confirmEmpty: false
    property string armed: ""          // mục đang chờ bấm lần hai để xoá vĩnh viễn
    property string selected: ""       // mục đang chọn: Space = xem nhanh (Quick Look)
    function look(id) { if (id) QuickLook.show(Trash.dir + "/files/" + id); }

    function when(d) {
        if (!d) return "";
        const t = new Date(d);
        if (isNaN(t)) return d;
        const now = new Date();
        const hm = Qt.formatTime(t, Prefs.clock24 ? "HH:mm" : "h:mm AP");
        if (t.toDateString() === now.toDateString()) return "Today " + hm;
        const y = new Date(now); y.setDate(now.getDate() - 1);
        if (t.toDateString() === y.toDateString()) return "Yesterday " + hm;
        return Qt.formatDate(t, "d MMM yyyy");
    }
    function where(p) {
        const home = Quickshell.env("HOME");
        const d = p.slice(0, p.lastIndexOf("/")) || "/";
        return d === home ? "Home" : d.startsWith(home + "/") ? "~" + d.slice(home.length) : d;
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

    Item {
        id: panel
        anchors.fill: parent
        focus: true
        transformOrigin: Item.Top
        Keys.onEscapePressed: { if (win.confirmEmpty) win.confirmEmpty = false; else win.close(); }
        Keys.onSpacePressed: win.look(win.selected || (Trash.items[0]?.id ?? ""))
        Keys.onUpPressed: { const i = Trash.items.findIndex(x => x.id === win.selected); if (i > 0) win.selected = Trash.items[i - 1].id; }
        Keys.onDownPressed: { const i = Trash.items.findIndex(x => x.id === win.selected); if (i < Trash.items.length - 1) win.selected = Trash.items[i + 1].id; }
        ParallelAnimation {
            id: intro
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; from: 0.98; to: 1; duration: 300; easing.type: Easing.OutCubic }
        }

        // thả file vào cửa sổ = bỏ vào thùng rác
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: d => { Trash.put(d.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")))); d.acceptProposedAction(); }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: 10; radius: 18; z: 30
            color: Theme.tint(0.12); border.width: 2; border.color: Theme.accent
            visible: drop.containsDrag
            Text { anchors.centerIn: parent; text: "Drop to move to Trash"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
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
                AppIcon { anchors.verticalCenter: parent.verticalCenter; size: 30; name: Trash.full ? "trash-full" : "trash" }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Trash"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
                    Text {
                        text: Trash.count === 0 ? "Empty" : Trash.count + (Trash.count === 1 ? " item" : " items") + " · " + Trash.human(Trash.bytes)
                        color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 20
                y: 40
                spacing: 8
                Btn { label: "Open in Files"; onClicked: Quickshell.execDetached(["nautilus", "trash:///"]) }
                Btn { label: "Empty Trash"; danger: true; enabled_: Trash.count > 0; onClicked: win.confirmEmpty = true }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
        }

        // ---------- danh sách ----------
        ListView {
            id: list
            anchors.top: head.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 12
            anchors.bottomMargin: 30
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Trash.items
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool isArmed: win.armed === modelData.id
                readonly property bool isSel: win.selected === modelData.id
                width: list.width
                height: 58
                radius: 14
                color: isSel ? Theme.tint(0.18) : rm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                // bấm để chọn · bấm đúp hoặc Space để xem nhanh
                MouseArea {
                    id: rm; anchors.fill: parent; hoverEnabled: true
                    onClicked: { win.selected = row.modelData.id; panel.forceActiveFocus(); }
                    onDoubleClicked: win.look(row.modelData.id)
                }
                Image {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34; sourceSize: Qt.size(68, 68)
                    source: win.iconFor(row.modelData)
                    asynchronous: true
                }
                Column {
                    x: 62; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 62 - actions.width - 110
                    Text { width: parent.width; elide: Text.ElideMiddle; text: row.modelData.name; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                    Text {
                        width: parent.width; elide: Text.ElideLeft
                        text: "From " + win.where(row.modelData.orig) + "  ·  " + win.when(row.modelData.date)
                        color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                    }
                }
                Text {
                    anchors.right: actions.left; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    text: Trash.human(row.modelData.size); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                }
                Row {
                    id: actions
                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: rm.containsMouse || row.isArmed ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Btn { label: "Put Back"; onClicked: Trash.restore([row.modelData.id]) }
                    Btn {
                        label: row.isArmed ? "Delete forever?" : "Delete"
                        danger: row.isArmed
                        onClicked: { if (row.isArmed) { win.armed = ""; Trash.remove([row.modelData.id]); } else { win.armed = row.modelData.id; disarm.restart(); } }
                    }
                }
            }
        }
        Timer { id: disarm; interval: 4000; onTriggered: win.armed = "" }

        // thùng rác trống
        Column {
            visible: Trash.count === 0 && !Trash.loading
            anchors.centerIn: list
            spacing: 10
            AppIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 84; name: "trash" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Trash is empty"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Drag files onto the Trash in the Dock to delete them."; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
        Text {
            visible: Trash.count > 0
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
            text: "Space — Quick Look  ·  double-click to preview"
            color: "#636366"; font.family: Theme.font; font.pixelSize: 11
        }

        // ---------- hỏi trước khi dọn sạch ----------
        Rectangle {
            anchors.fill: parent; z: 40
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: opacity > 0.01
            opacity: win.confirmEmpty ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent; onClicked: win.confirmEmpty = false }
            Rectangle {
                anchors.centerIn: parent
                width: 400; height: 196; radius: 22
                color: Qt.rgba(0.1, 0.1, 0.14, 0.98)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                scale: win.confirmEmpty ? 1 : 0.92
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.32 } }
                MouseArea { anchors.fill: parent }
                Column {
                    x: 24; y: 22; width: parent.width - 48; spacing: 10
                    Row {
                        spacing: 12
                        AppIcon { size: 40; name: "trash-full" }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Empty the Trash?"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold
                        }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: Trash.count + (Trash.count === 1 ? " item" : " items") + " (" + Trash.human(Trash.bytes) + ") will be erased for good. You can't undo this."
                        color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 12
                    }
                    Item { width: 1; height: 6 }
                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        Btn { label: "Cancel"; onClicked: win.confirmEmpty = false }
                        Btn { label: "Empty Trash"; danger: true; primary: true; onClicked: { win.confirmEmpty = false; Trash.empty(); } }
                    }
                }
            }
        }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool danger: false
        property bool primary: false
        property bool enabled_: true
        signal clicked()
        width: bl.implicitWidth + 26
        height: 30
        radius: 15
        opacity: enabled_ ? 1 : 0.4
        color: primary ? (bm.containsMouse ? "#FF7A73" : "#FF5F57")
             : danger ? (bm.containsMouse ? Qt.rgba(1, 0.37, 0.34, 0.32) : Qt.rgba(1, 0.37, 0.34, 0.18))
             : (bm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: bm.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Text { id: bl; anchors.centerIn: parent; text: b.label; color: b.danger && !b.primary ? "#FF8A84" : "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: bm; anchors.fill: parent; enabled: b.enabled_; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
