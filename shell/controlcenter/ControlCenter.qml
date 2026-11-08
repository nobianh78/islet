import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../theme"
import "../services"
import "../common"
import "../island"
import "../settings"

// Trung tâm điều khiển: bật ra từ góc phải trên khi bấm cụm trạng thái trên thanh.
PanelWindow {
    id: win

    anchors { top: true; right: true }
    margins { top: 50; right: 12 }
    readonly property real unit: 52        // ô tròn 52 px; viên thuốc = 2 ô; thanh trượt = 4 ô
    readonly property real gap: 10
    readonly property real pad: 12          // lề trong suốt quanh các ô (để dấu − ở góc vẫn bấm được)
    implicitWidth: panel.width + (editing ? picker.width + 12 : 0)
    implicitHeight: panel.height + 16
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: true

    WlrLayershell.namespace: "islet-cc"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Ui.controlCenterOpen
    // Giữ cửa sổ sống trong lúc chạy animation đóng.
    visible: open || panel.opacity > 0.01

    mask: Region { item: panel; Region { item: picker } }

    // Bấm ra ngoài thì đóng.
    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Ui.controlCenterOpen = false
    }

    readonly property var bt: Bluetooth.defaultAdapter

    property bool editing: false
    onOpenChanged: if (!open) editing = false

    // Danh mục: wide = chiếm cả hàng. Thêm mục mới = thêm một Component bên dưới và một dòng ở đây.
    readonly property var defs: ({
        net:        { size: "pill", icon: "wifi",       color: "#2DD4BF", title: "Wi-Fi / Network",  hint: "Connect and switch networks", comp: cNet },
        bt:         { size: "pill", icon: "bluetooth",  color: "#5B8CFF", title: "Bluetooth",        hint: "Turn Bluetooth on or off",    comp: cBt },
        airplane:   { size: "icon", icon: "wifi-off",   color: "#FF9F0A", title: "Airplane mode",    hint: "Block Wi-Fi and Bluetooth",   comp: cAir },
        night:      { size: "icon", icon: "moon",       color: "#FFB547", title: "Night Light",      hint: "Warmer screen at night",      comp: cNight },
        saver:      { size: "icon", icon: "bolt",       color: "#34C77B", title: "Battery saver",    hint: "Make the battery last longer", comp: cSaver },
        focus:      { size: "icon", icon: "sparkle",       color: "#8B7CFF", title: "Focus",            hint: "Silence banners, dim the rest", comp: cFocus },
        dnd:        { size: "icon", icon: "bell",       color: "#FF6B97", title: "Do Not Disturb",   hint: "Mute notifications",          comp: cDnd },
        theme:      { size: "icon", icon: "palette",        color: "#8B7CFF", title: "Dark mode",        hint: "Switch between dark and light", comp: cTheme },
        shot:       { size: "icon", icon: "image",      color: "#2DD4BF", title: "Screenshot",       hint: "Capture an area",             comp: cShot },
        rec:        { size: "icon", icon: "record",     color: "#FF453A", title: "Screen recording", hint: "Record the screen",           comp: cRec },
        lock:       { size: "icon", icon: "lock",       color: "#8E8E93", title: "Lock screen",      hint: "Lock this computer",          comp: cLock },
        timer:      { size: "icon", icon: "timer",      color: "#FF9F0A", title: "Timer",            hint: "Open the timer on the island", comp: cTimer },
        clip:       { size: "icon", icon: "clipboard",  color: "#5B8CFF", title: "Clipboard",        hint: "Open clipboard history",      comp: cClip },
        taskmgr:    { size: "icon", icon: "activity",   color: "#34C77B", title: "Task Manager",     hint: "See what is running",         comp: cTask },
        volume:     { size: "wide", icon: "volume",     color: "#8E8E93", title: "Volume",           hint: "Speaker volume and output",   comp: cVol },
        brightness: { size: "wide", icon: "sun",        color: "#FFB547", title: "Brightness",       hint: "Screen brightness",           comp: cBri },
        mic:        { size: "wide", icon: "mic",        color: "#FF9F0A", title: "Microphone",       hint: "Shows while an app is recording", comp: cMic },
        media:      { size: "wide", icon: "music",      color: "#FF6B97", title: "Now playing",      hint: "Music player",                comp: cMedia }
    })
    // mục nào hiện: micro chỉ khi có app đang thu, trình phát chỉ khi có nhạc (đang sửa thì hiện hết)
    function shown(id) {
        if (editing) return true;
        if (id === "mic") return Privacy.mic;
        if (id === "media") return Media.hasPlayer;
        return true;
    }
    // kéo thả: đưa mục `id` tới vị trí của mục thứ `to` trong danh sách đang hiện
    function layoutReorder(id, to) {
        const a = Prefs.ccLayout.filter(x => defs[x]), i = a.indexOf(id);
        if (i < 0 || to < 0 || to >= a.length || to === i) return;
        a.splice(i, 1);
        a.splice(to, 0, id);
        Prefs.set("ccLayout", a);
    }
    function layoutRemove(id) { Prefs.set("ccLayout", Prefs.ccLayout.filter(x => x !== id)); }
    function layoutAdd(id) { Prefs.set("ccLayout", Prefs.ccLayout.concat([id])); }
    // đóng bảng rồi mới chụp / quay để bảng không lọt vào ảnh
    function afterClose(fn) { Ui.controlCenterOpen = false; later.fn = fn; later.restart(); }
    Timer { id: later; property var fn; interval: 450; onTriggered: fn() }

    // Không có nền: mỗi ô tự là một viên kính (giống Control Center của macOS mới)
    Item {
        id: panel
        anchors.right: parent.right
        width: 4 * win.unit + 3 * win.gap + 2 * win.pad
        height: content.implicitHeight + 2 * win.pad

        transformOrigin: Item.TopRight
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.86
        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 140; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.3; epsilon: 0.002 } }

        Keys.onEscapePressed: Ui.controlCenterOpen = false
        focus: win.open

        Column {
            id: content
            x: win.pad
            y: win.pad
            width: parent.width - 2 * win.pad
            spacing: 12

            // Các mục do người dùng sắp xếp (Prefs.ccLayout). Khi sửa: kéo để đổi chỗ, bấm dấu − để bỏ.
            Flow {
                id: grid
                width: parent.width
                spacing: win.gap
                Repeater {
                    id: rep
                    model: Prefs.ccLayout.filter(id => win.defs[id])
                    Item {
                        id: cell
                        required property string modelData
                        required property int index
                        readonly property var d: win.defs[modelData]
                        property real dx: 0
                        property real dy: 0
                        visible: win.shown(modelData)
                        width: d.size === "icon" ? win.unit : d.size === "pill" ? 2 * win.unit + win.gap : grid.width
                        height: ld.height
                        z: drag.pressed ? 10 : 0
                        opacity: drag.pressed ? 0.85 : 1
                        scale: drag.pressed ? 1.04 : 1
                        transform: Translate { x: cell.dx; y: cell.dy }
                        Loader {
                            id: ld
                            width: parent.width
                            height: item ? item.implicitHeight : 0
                            sourceComponent: cell.d.comp
                            enabled: !win.editing
                            onLoaded: if (item.compact !== undefined) item.compact = cell.d.size === "icon"
                        }
                        // chế độ sửa: giữ để kéo, dấu − ở góc để bỏ
                        MouseArea {
                            id: drag
                            anchors.fill: parent
                            enabled: win.editing
                            visible: win.editing
                            preventStealing: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property point start
                            onPressed: m => { start = mapToItem(grid, m.x, m.y); }
                            onPositionChanged: m => {
                                if (!pressed) return;
                                const g = mapToItem(grid, m.x, m.y);
                                cell.dx = g.x - start.x; cell.dy = g.y - start.y;
                            }
                            onReleased: m => {
                                const g = mapToItem(grid, m.x, m.y);
                                cell.dx = 0; cell.dy = 0;
                                for (let i = 0; i < rep.count; i++) {
                                    const it = rep.itemAt(i);
                                    if (it && it.visible && it !== cell && g.x >= it.x && g.x < it.x + it.width && g.y >= it.y && g.y < it.y + it.height) {
                                        win.layoutReorder(cell.modelData, i);
                                        break;
                                    }
                                }
                            }
                        }
                        Rectangle {
                            visible: win.editing
                            x: -7; y: -7; width: 22; height: 22; radius: 11
                            color: rm.containsMouse ? "#FF453A" : "#6C6C70"
                            border.width: 1.5; border.color: Qt.rgba(1, 1, 1, 0.9)
                            Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: "#FFFFFF" }
                            MouseArea { id: rm; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.layoutRemove(cell.modelData) }
                        }
                    }
                }
            }

            // Chân: Edit + Cài đặt, mỗi nút là một viên kính
            Item {
                width: parent.width
                height: 30
                Glass {
                    anchors.right: gear.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    width: editLabel.implicitWidth + 24; height: 28; radius: 14
                    color: win.editing ? Theme.accent : em.containsMouse ? Theme.glassHover : Theme.glassFill
                    Text { id: editLabel; anchors.centerIn: parent; text: win.editing ? "Done" : "Edit"; color: win.editing ? "#FFFFFF" : Theme.label; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.editing = !win.editing }
                }
                Glass {
                    id: gear
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14
                    color: gm.containsMouse ? Theme.glassHover : Theme.glassFill
                    TIcon {
                        anchors.centerIn: parent; name: "settings"; size: 14
                        rotation: gm.containsMouse ? 60 : 0
                        Behavior on rotation { SpringAnimation { spring: 3; damping: 0.3 } }
                    }
                    MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.openSettings("") }
                }
            }
        }

        // ---------- các mục (mỗi Component là một ô / thanh trượt) ----------
        Component { id: cNet; Tile {
            icon: Net.icon
            title: Net.kind === "ethernet" ? "Network" : "Wi-Fi"
            subtitle: Net.label
            checked: Net.connected
            available: Net.wifiPresent || Net.connected
            onToggled: if (Net.wifiPresent) Net.toggleWifi()
        } }
        Component { id: cBt; Tile {
            icon: "bluetooth"
            title: "Bluetooth"
            subtitle: !win.bt ? "None" : win.bt.enabled ? "On" : "Off"
            checked: win.bt?.enabled ?? false
            available: win.bt !== null
            onColor: Theme.violet
            onToggled: if (win.bt) win.bt.enabled = !win.bt.enabled
        } }
        Component { id: cAir; Tile {
            icon: "wifi-off"
            title: "Airplane mode"
            subtitle: Net.airplane ? "On" : "Off"
            checked: Net.airplane
            onColor: "#FF9F0A"
            onToggled: Net.toggleAirplane()
        } }
        Component { id: cNight; Tile {
            icon: "moon"
            title: "Night Light"
            subtitle: NightLight.active ? (Prefs.nightMode === "schedule" ? "Until " + Prefs.nightTo : "On") : Prefs.nightMode === "schedule" ? "From " + Prefs.nightFrom : "Off"
            checked: NightLight.active
            onColor: "#FFB547"
            onToggled: NightLight.toggle()
        } }
        Component { id: cSaver; Tile {
            icon: "bolt"
            title: "Battery saver"
            subtitle: PowerProfiles.profile === PowerProfile.PowerSaver ? "On" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"
            checked: PowerProfiles.profile === PowerProfile.PowerSaver
            onColor: "#34C77B"
            onToggled: PowerProfiles.profile = checked ? PowerProfile.Balanced : PowerProfile.PowerSaver
        } }
        Component { id: cFocus; Tile {
            icon: "sparkle"
            title: "Focus"
            subtitle: Ui.focusMode ? "On" : "Off"
            checked: Ui.focusMode
            onColor: Theme.violet
            onToggled: Ui.focusMode = !Ui.focusMode
        } }
        Component { id: cDnd; Tile {
            icon: "bell"
            title: "Do Not Disturb"
            subtitle: Prefs.dnd ? "On" : "Off"
            checked: Prefs.dnd
            onColor: "#FF6B97"
            onToggled: Prefs.set("dnd", !Prefs.dnd)
        } }
        Component { id: cTheme; Tile {
            icon: "palette"
            title: "Dark mode"
            subtitle: Theme.light ? "Off" : "On"
            checked: !Theme.light
            onColor: Theme.violet
            onToggled: Prefs.set("themeMode", Theme.light ? "dark" : "light")
        } }
        Component { id: cLock; Tile {
            icon: "lock"
            title: "Lock screen"
            onToggled: win.afterClose(() => Ui.lock())
        } }
        Component { id: cTimer; Tile {
            icon: "timer"
            title: "Timer"
            onToggled: win.afterClose(() => Quickshell.execDetached(["qs", "ipc", "call", "island", "open", "timer"]))
        } }
        Component { id: cClip; Tile {
            icon: "clipboard"
            title: "Clipboard"
            onToggled: win.afterClose(() => Quickshell.execDetached(["qs", "ipc", "call", "island", "open", "clipboard"]))
        } }
        Component { id: cTask; Tile {
            icon: "activity"
            title: "Task Manager"
            onToggled: { Ui.controlCenterOpen = false; Ui.toggleTask(); }
        } }
        Component { id: cShot; Tile {
            icon: "image"
            title: "Screenshot"
            subtitle: "Select an area"
            onColor: Theme.teal
            onToggled: win.afterClose(() => Quickshell.execDetached(["islet-shot", "area"]))
        } }
        Component { id: cRec; Tile {
            icon: "record"
            title: Recorder.recording ? "Stop" : "Screen recording"
            subtitle: Recorder.recording ? Recorder.text : "Select an area"
            checked: Recorder.recording
            onColor: "#FF453A"
            onToggled: Recorder.recording ? Recorder.stop() : win.afterClose(() => Recorder.start(true))
        } }
        Component { id: cVol; Item {
            implicitHeight: 52 + (Audio.sinks.length > 1 ? 20 : 0)
            Slider {
                width: parent.width
                title: "Volume"
                value: Audio.muted ? 0 : Math.min(1, Audio.volume)
                available: Audio.sink !== null
                onMoved: v => Audio.setVolume(v)
            }
            // bấm để đổi loa / tai nghe kế tiếp
            Text {
                visible: Audio.sinks.length > 1
                x: 6; y: 56; width: parent.width - 12
                text: "Output: " + (Audio.sink?.description || Audio.sink?.name || "—") + "  \u203A"
                elide: Text.ElideRight
                color: om.containsMouse ? Theme.label : Theme.fg(0.68)
                font.family: Theme.font; font.pixelSize: 11
                MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.nextSink() }
            }
        } }
        Component { id: cBri; Slider {
            title: "Brightness"
            value: Brightness.value
            fill: Theme.amber
            available: Brightness.available
            label: v => Brightness.available ? Math.round(v * 100) + "%" : "No backlight found"
            onMoved: v => Brightness.set(v)
        } }
        Component { id: cMic; Slider {
            title: Privacy.mic ? "Microphone \u00B7 " + (Privacy.micApps[0] ?? "") : "Microphone"
            value: Audio.micVolume
            fill: "#FF9F0A"
            available: Audio.source !== null
            onMoved: v => Audio.setMic(v)
        } }
        Component { id: cMedia; Rectangle {
                implicitHeight: 72
                radius: 18
                color: Theme.fg(0.10)

                Artwork {
                    id: art
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    radius: 12
                    source: Media.artUrl
                }
                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 12
                    anchors.right: controls.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: Media.title
                        color: Theme.label
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Media.artist
                        color: Theme.fg(0.68)
                        font.family: Theme.font
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    IconButton {
                        implicitWidth: 38; implicitHeight: 38; iconSize: 18
                        icon: Qt.resolvedUrl(Media.playing ? "../assets/icons/pause.svg" : "../assets/icons/play.svg")
                        fill: Theme.label
                        onClicked: Media.toggle()
                    }
                    IconButton {
                        implicitWidth: 38; implicitHeight: 38; iconSize: 18
                        icon: Qt.resolvedUrl("../assets/icons/next.svg")
                        active: Media.active?.canGoNext ?? false
                        onClicked: Media.next()
                    }
                }
            } }
    }

    // khung "Add controls" bên trái khi đang sửa (giống macOS): bấm một mục để thêm vào
    Glass {
        id: picker
        visible: width > 1
        anchors.left: parent.left
        y: 0
        width: win.editing ? 300 : 0
        height: panel.height
        radius: 28
        color: Theme.surface(0.55)
        clip: true
        property string q: ""

        Text { x: 18; y: 16; text: "Add controls"; color: Theme.label; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold }
        Rectangle {
            x: 14; y: 46; width: parent.width - 28; height: 30; radius: 15
            color: Theme.fg(find.activeFocus ? 0.18 : 0.1)
            TIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 12; opacity: 0.6 }
            TextInput {
                id: find
                x: 30; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter
                color: Theme.label; selectionColor: Theme.accent
                font.family: Theme.font; font.pixelSize: 12
                clip: true
                onTextChanged: picker.q = text.trim().toLowerCase()
            }
            Text { visible: find.text === "" ; x: 30; anchors.verticalCenter: parent.verticalCenter; text: "Search controls"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
        }
        ListView {
            x: 6; y: 88; width: parent.width - 12; height: parent.height - 88 - 58
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Object.keys(win.defs).filter(id => !picker.q || (win.defs[id].title + " " + win.defs[id].hint).toLowerCase().includes(picker.q))
            delegate: Rectangle {
                required property string modelData
                readonly property var d: win.defs[modelData]
                readonly property bool added: Prefs.ccLayout.indexOf(modelData) >= 0
                width: ListView.view.width; height: 52; radius: 14
                color: pm.containsMouse && !added ? Theme.fg(0.1) : "transparent"
                Rectangle {
                    x: 8; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; radius: 18
                    color: parent.d.color
                    TIcon { anchors.centerIn: parent; name: parent.parent.d.icon; size: 18; color: "#FFFFFF" }
                }
                Column {
                    x: 54; width: parent.width - 54 - 44; anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; text: parent.parent.d.title; color: Theme.label; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { width: parent.width; text: parent.parent.d.hint; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 12
                    color: parent.added ? "transparent" : Theme.accent
                    TIcon { anchors.centerIn: parent; name: parent.parent.added ? "check" : "plus"; size: 13; color: parent.parent.added ? Theme.muted : "#FFFFFF" }
                }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; enabled: !parent.added; cursorShape: Qt.PointingHandCursor; onClicked: win.layoutAdd(parent.modelData) }
            }
        }
        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
            spacing: 8
            Chip { label: "Reset"; onClicked: Prefs.set("ccLayout", Prefs.defaultCcLayout) }
            Chip { label: "Done"; on: true; onClicked: win.editing = false }
        }
    }
}
