import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Dock của Islet.
// Thay vì phóng to kiểu sóng, dock có một "viên sáng lỏng" màu theo app nằm sau icon:
// nó bị hút vào icon gần con trỏ nhất, kéo dài như giọt nước khi trượt sang icon khác rồi co lại.
PanelWindow {
    id: win

    anchors.bottom: true
    implicitWidth: 560
    implicitHeight: dragFrom >= 0 ? 180 : 120          // chừa chỗ cho icon nhấc lên + nhãn tên (cao hơn lúc kéo icon lên)
    // tự ẩn: không giữ chỗ dưới đáy màn hình (cửa sổ dùng được hết chiều cao)
    exclusiveZone: Prefs.dockAutohide ? 0 : 78
    color: "transparent"

    WlrLayershell.namespace: "islet-dock"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region { item: hit }

    readonly property real base: Prefs.dockSize
    readonly property real gap: 8
    readonly property real pad: 8
    readonly property real sepWidth: 17   // vạch ngăn 1px + khe hai bên

    // App quen thuộc: tên tiếng Việt + icon Islet (shell/assets/apps) + màu viên sáng.
    readonly property var known: ({
        "org.gnome.Nautilus": { label: "Files",              icon: "files",    tile: "#9D6BFF", ids: ["org.gnome.Nautilus", "nautilus"] },
        "firefox":            { label: "Firefox",          icon: "browser",  tile: "#3B8BFF", ids: ["firefox"] },
        "kitty":              { label: "Terminal",         icon: "terminal", tile: "#34D399", ids: ["kitty"] },
        "code-oss":           { label: "Code",             icon: "code",     tile: "#3B6BFF", ids: ["code-oss", "code"] },
        "mpv":                { label: "Video Player", icon: "video",    tile: "#FF6B5C", ids: ["mpv"] },
        "islet-store":        { label: "Store",         icon: "store",    tile: "#5B8CFF", ids: [] }
    })

    function entryFor(id) {
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }
    function makeApp(id, pinned) {
        const e = entryFor(id);
        const k = known[id] ?? known[e?.id ?? ""];
        return {
            key: e?.id ?? id,
            label: k?.label ?? e?.name ?? id,
            icon: k?.icon ?? Theme.appKey(e?.id ?? id),
            iconUrl: (k || Theme.appKey(e?.id ?? id)) ? "" : (Quickshell.iconPath(e?.icon ?? id, true) || Quickshell.iconPath("application-x-executable", true)),
            tile: k?.tile ?? Theme.violet,
            ids: k?.ids ?? [id, (e?.id ?? id), (e?.id ?? id).toLowerCase()],
            entry: e,
            pinId: id,
            pinned: pinned
        };
    }

    // Ứng dụng · [app ghim] · [app đang chạy chưa ghim] | Cài đặt
    readonly property var apps: {
        DesktopEntries.applications.values;   // dựng lại khi danh sách app quét xong / thay đổi
        const out = [{ key: "launcher", label: "Apps", icon: "apps", tile: "#8B7CFF", ids: [], launcher: true }];
        for (const id of DockPins.pins) if (id !== "islet-settings") out.push(makeApp(id, true));   // Cài đặt luôn ở cuối dock
        const tl = ToplevelManager.toplevels.values;
        for (let i = 0; i < tl.length; i++) {
            const cls = tl[i].appId;
            if (!cls || cls === "org.quickshell") continue;
            if (out.some(a => a.ids.indexOf(cls) >= 0)) continue;
            out.push(makeApp(cls, false));
        }
        out.push({ key: "settings", label: "Settings", icon: "settings", tile: "#FF8A5C", ids: [], system: true });
        // thùng rác (giống macOS): thả file lên để xoá, bấm để mở
        out.push({ key: "trash", label: Trash.full ? "Trash · " + Trash.count + (Trash.count === 1 ? " item" : " items") : "Trash",
                   icon: Trash.full ? "trash-full" : "trash", tile: "#8A93A8", ids: [], trash: true });
        return out;
    }
    readonly property int appCount: apps.length - 2       // vạch ngăn đứng trước Cài đặt · Thùng rác

    function windowsOf(ids) {
        const out = [];
        const tl = ToplevelManager.toplevels.values;
        for (let i = 0; i < tl.length; i++)
            if (ids.indexOf(tl[i].appId) >= 0) out.push(tl[i]);
        return out;
    }
    readonly property string activeId: ToplevelManager.activeToplevel?.activated ? (ToplevelManager.activeToplevel.appId ?? "") : ""

    function launch(app) {
        if (app.trash) { Ui.openTrash(); return; }
        if (app.system) { Ui.openSettings(""); return; }      // mở, hoặc đưa cửa sổ Cài đặt lên / lấy lại khi đang thu nhỏ
        if (app.launcher) { Ui.toggleLauncher(); return; }
        if (app.key === "islet-store") { Ui.openStore(); return; }      // cửa sổ Cửa hàng của Islet: mở / đưa lên / lấy lại
        const hidden = Windows.minimizedOf(app.ids);
        if (hidden.length > 0) { Windows.restore(hidden[0]); return; }
        const open = windowsOf(app.ids);
        if (open.length > 0) { open[0].activate(); return; }
        newWindow(app);
    }
    function newWindow(app) {
        if (app.key === "islet-store") { Ui.openStore(); return; }
        if (app.icon) Ui.announceLaunch(app.label, app.icon, app.tile);
        else Ui.announceLaunchUrl(app.label, app.iconUrl);
        // tra lại lúc bấm (phòng khi lúc dựng dock danh sách app chưa quét xong)
        const e = app.entry ?? entryFor(app.key) ?? app.ids.map(i => entryFor(i)).find(x => x) ?? null;
        if (e) Ui.launchEntry(e);
        else Quickshell.execDetached(["sh", "-c", app.key]);
    }

    // ---------------- kéo thả: đổi chỗ / kéo lên để bỏ ghim / kéo app đang chạy vào để ghim ----------------
    property int dragFrom: -1           // chỉ số trong apps của icon đang kéo
    property real dragX: 0              // con trỏ, so với mép trái hàng icon
    property real dragDy: 0             // < 0 = kéo lên
    readonly property int pinnedEnd: DockPins.pins.filter(p => p !== "islet-settings").length   // apps[1 … pinnedEnd] là app ghim
    // kéo icon ghim thả lên thùng rác cũng là bỏ ghim (như macOS)
    readonly property bool overTrash: dragFrom >= 0 && (apps[dragFrom]?.pinned ?? false) && Math.abs(dragX - centerOf(apps.length - 1)) < base * 0.6
    readonly property bool removing: dragFrom >= 0 && (apps[dragFrom]?.pinned ?? false) && (dragDy < -base * 1.2 || overTrash)
    readonly property int dragTo: {
        if (dragFrom < 0 || removing) return dragFrom;
        const slot = Math.round((dragX - base / 2) / (base + gap));
        if (apps[dragFrom].pinned) return Math.max(1, Math.min(pinnedEnd, slot));
        return slot >= 1 && slot <= pinnedEnd ? slot : dragFrom;    // app chưa ghim: thả vào giữa các app ghim = ghim
    }
    // icon khác nhường chỗ cho icon đang kéo
    function shiftOf(i) {
        if (dragFrom < 0 || i === dragFrom) return 0;
        const f = dragFrom, t = dragTo;
        if (removing) return i > f && i <= pinnedEnd ? -(base + gap) : 0;
        if (f < t && i > f && i <= t) return -(base + gap);
        if (t < f && i >= t && i < f) return base + gap;
        return 0;
    }
    function endDrag() {
        const a = apps[dragFrom], t = dragTo, from = dragFrom, rm = removing;
        dragFrom = -1;
        if (!a) return;
        if (rm) { DockPins.unpinApp(a); Ui.toast("Removed " + a.label + " from the Dock", "", ""); }
        else if (a.pinned && t !== from) DockPins.pinAt(a.pinId, t - 1);
        else if (!a.pinned && t !== from) { DockPins.pinAt(a.key, t - 1); Ui.toast("Pinned " + a.label + " to the Dock", "", ""); }
    }
    // dock dựng lại khi danh sách ghim đổi → không cho icon bật lên lại như lúc khởi động
    property bool introDone: false
    Timer { running: true; interval: 2500; onTriggered: win.introDone = true }

    // ---------------- menu chuột phải ----------------
    DockMenu {
        id: menu
        screen: win.screen
        dock: win
    }
    function openMenu(index) {
        const sx = (win.screen?.width ?? win.width) / 2 - win.width / 2;
        menu.openFor(apps[index], sx + plate.x + pad + centerOf(index));
    }

    // Tâm icon thứ i, so với mép trái hàng icon.
    function centerOf(i) {
        return i * (base + gap) + base / 2 + (i >= appCount ? sepWidth - gap : 0);
    }

    // ---------------- Theo dõi con trỏ ----------------
    HoverHandler { id: hover }
    readonly property real px: hover.hovered ? hover.point.position.x - plate.x - pad : -1000
    // Icon gần con trỏ nhất.
    readonly property int nearest: {
        if (px < -999) return -1;
        let best = 0, bd = 1e9;
        for (let i = 0; i < apps.length; i++) {
            const d = Math.abs(px - centerOf(i));
            if (d < bd) { bd = d; best = i; }
        }
        return best;
    }
    property int lastNearest: 0
    onNearestChanged: if (nearest >= 0) lastNearest = nearest

    Item {
        id: hit
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: plate.width
        height: autoHide.hidden ? 6 : plate.height + plate.anchors.bottomMargin + (hover.hovered ? 44 : 0)
    }

    // ---- tự ẩn dock (Cài đặt › Island & Dock): rời chuột 0,7 giây thì trượt xuống, chạm đáy màn hình thì hiện ----
    Item {
        id: autoHide
        property bool hidden: false
        readonly property bool wantHidden: Prefs.dockAutohide && !hover.hovered && !Ui.launcherOpen && !menu.visible
        onWantHiddenChanged: { if (wantHidden) hideLater.restart(); else { hideLater.stop(); hidden = false; } }
        Timer { id: hideLater; interval: 700; onTriggered: autoHide.hidden = autoHide.wantHidden }
        property real v: hidden ? 0 : 1
        Behavior on v { SpringAnimation { spring: 4; damping: 0.38; epsilon: 0.005 } }
    }

    // ---------------- Tấm kính ----------------
    // trượt vào sau khi mở khoá (nối tiếp hiệu ứng của màn hình khoá)
    Item {
        id: reveal
        property real v: Ui.locked ? 0 : 1
        Behavior on v {
            SequentialAnimation {
                PauseAnimation { duration: Ui.locked ? 0 : 220 }
                NumberAnimation { duration: Ui.locked ? 0 : 750; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }
        }
    }

    Glass {
        transform: Translate { y: 110 * (1 - reveal.v * autoHide.v) }
        id: plate
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: row.width + win.pad * 2
        height: win.base + win.pad * 2
        radius: win.base * 0.3 + win.pad
        color: Ui.dockDropHover ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
        border.color: Ui.dockDropHover ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
        border.width: Ui.dockDropHover ? 2 : 1
        scale: Ui.dockDropHover ? 1.05 : 1
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.005 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on width { SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.1 } }

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 2
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.28) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }

        // ---------------- Viên sáng lỏng ----------------
        Item {
            id: lens
            readonly property real targetX: win.pad + win.centerOf(win.lastNearest)
            property real cx: targetX
            Behavior on cx { SpringAnimation { spring: 3.2; damping: 0.36; epsilon: 0.05 } }

            // Kéo dài theo quãng đường còn lại tới đích → trông như giọt nước đang chảy.
            readonly property real stretch: Math.min(40, Math.abs(targetX - cx) * 0.55)
            readonly property bool shown: win.nearest >= 0
            readonly property color tint: win.apps[win.lastNearest].tile

            x: cx - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: win.base + 10 + stretch
            height: (win.base + 10) * (1 - stretch / 220)
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.005 } }

            // Quầng màu mềm phía sau.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 4
                height: parent.height + 2
                radius: height / 2.4
                color: lens.tint
                opacity: 0.32
                Behavior on color { ColorAnimation { duration: 260 } }
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1 }
            }
            // Mặt viên sáng.
            Rectangle {
                anchors.fill: parent
                radius: Math.min(height / 2, win.base * 0.3 + 5)
                color: Qt.rgba(1, 1, 1, 0.07)
                border.color: Qt.rgba(1, 1, 1, 0.20)
                border.width: 1
            }
        }
    }

    // ---------------- Icon ----------------
    Row {
        transform: Translate { y: 110 * (1 - reveal.v * autoHide.v) }
        id: row
        anchors.horizontalCenter: plate.horizontalCenter
        anchors.bottom: plate.bottom
        anchors.bottomMargin: win.pad
        spacing: win.gap

        Repeater {
            model: win.apps

            Row {
                id: slot
                required property var modelData
                required property int index
                spacing: win.gap

                // Vạch ngăn app / hệ thống, đặt trước icon hệ thống đầu tiên.
                Item {
                    visible: slot.index === win.appCount
                    width: 1
                    height: win.base
                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: win.base * 0.6
                        color: Qt.rgba(1, 1, 1, 0.18)
                    }
                }

                DockItem {
                    readonly property bool held: win.dragFrom === slot.index
                    draggable: !slot.modelData.system && !slot.modelData.launcher && !slot.modelData.trash
                    dropHover: slot.modelData.trash === true && (trashDrop.containsDrag || win.overTrash)
                    // thả file từ Files (hoặc bất kỳ app nào) lên thùng rác
                    DropArea {
                        id: trashDrop
                        anchors.fill: parent
                        anchors.margins: -8
                        enabled: slot.modelData.trash === true
                        keys: ["text/uri-list"]
                        onDropped: d => {
                            Trash.put(d.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(x => x.startsWith("/")));
                            d.acceptProposedAction();
                        }
                    }
                    Connections {
                        target: Trash
                        function onReceived() { if (slot.modelData.trash) item.receive(); }
                    }
                    playIntro: !win.introDone
                    z: held ? 10 : 0
                    opacity: held && win.removing ? 0.45 : 1
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    transform: Translate {
                        x: item.held ? win.dragX - win.centerOf(slot.index) : win.shiftOf(slot.index)
                        y: item.held ? Math.max(-50, Math.min(0, win.dragDy)) : 0
                        Behavior on x { enabled: !item.held; SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.1 } }
                        Behavior on y { enabled: !item.held; SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.1 } }
                    }
                    onDragStarted: { win.dragFrom = slot.index; menu.open = false; }
                    onDragMoved: (sx, dy) => { win.dragX = sx - row.x; win.dragDy = dy; }
                    onDragEnded: win.endDrag()
                    label: slot.modelData.label
                    icon: slot.modelData.icon
                    iconUrl: slot.modelData.iconUrl ?? ""
                    menuOpen: menu.open && menu.app?.key === slot.modelData.key
                    tile: slot.modelData.tile
                    order: slot.index
                    base: win.base
                    id: item
                    running: slot.modelData.trash ? Ui.trashOpen
                        : slot.modelData.system ? Ui.settingsOpen
                        : slot.modelData.launcher ? Ui.launcherOpen
                        : slot.modelData.key === "islet-store" ? Ui.storeOpen
                        : win.windowsOf(slot.modelData.ids).length > 0
                    minimized: slot.modelData.trash ? Windows.shellMinimized("Trash")
                        : slot.modelData.system ? Windows.settingsMinimized
                        : slot.modelData.key === "islet-store" ? Windows.storeMinimized
                        : !slot.modelData.launcher && running
                        && Windows.minimizedOf(slot.modelData.ids).length === win.windowsOf(slot.modelData.ids).length
                    focused: slot.modelData.trash ? Windows.shellActive("Trash")
                        : slot.modelData.system ? Windows.settingsActive
                        : slot.modelData.launcher ? Ui.launcherOpen
                        : slot.modelData.key === "islet-store" ? Windows.storeActive
                        : slot.modelData.ids.indexOf(win.activeId) >= 0
                    pointer: win.px < -999 ? -1000 : win.px - win.centerOf(slot.index)
                    onActivated: win.launch(slot.modelData)
                    onContextRequested: win.openMenu(slot.index)

                    Connections {
                        target: Windows
                        function onMinimizedApp(appId) {
                            if (slot.modelData.ids.indexOf(appId) >= 0) item.receive();
                        }
                    }
                }
            }
        }
    }

    // ---------------- Nhãn tên (một nhãn dùng chung, trượt theo viên sáng) ----------------
    Rectangle {
        transform: Translate { y: 110 * (1 - reveal.v * autoHide.v) }
        id: tag
        readonly property var app: win.dragFrom >= 0 ? win.apps[win.dragFrom] : win.apps[win.lastNearest]
        x: win.dragFrom >= 0 ? row.x + win.dragX - width / 2 : plate.x + lens.cx - width / 2
        anchors.bottom: plate.top
        anchors.bottomMargin: 8 + (win.dragFrom >= 0 ? -Math.max(-50, Math.min(0, win.dragDy)) : 0)
        width: tagText.implicitWidth + 20
        height: 24
        radius: 12
        color: Qt.rgba(0.04, 0.04, 0.08, 0.88)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        opacity: lens.shown || win.dragFrom >= 0 ? 1 : 0
        scale: lens.shown || win.dragFrom >= 0 ? 1 : 0.85
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.005 } }
        Behavior on width { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.1 } }

        Text {
            id: tagText
            anchors.centerIn: parent
            text: win.removing ? "Release to remove from Dock" : (tag.app?.label ?? "")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
