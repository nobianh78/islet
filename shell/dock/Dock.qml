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
    implicitHeight: 120          // chừa chỗ cho icon nhấc lên + nhãn tên
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
            pinned: pinned
        };
    }

    // Ứng dụng · [app ghim] · [app đang chạy chưa ghim] | Cài đặt
    readonly property var apps: {
        DesktopEntries.applications.values;   // dựng lại khi danh sách app quét xong / thay đổi
        const out = [{ key: "launcher", label: "Apps", icon: "apps", tile: "#8B7CFF", ids: [], launcher: true }];
        for (const id of DockPins.pins) out.push(makeApp(id, true));
        const tl = ToplevelManager.toplevels.values;
        for (let i = 0; i < tl.length; i++) {
            const cls = tl[i].appId;
            if (!cls || cls === "org.quickshell") continue;
            if (out.some(a => a.ids.indexOf(cls) >= 0)) continue;
            out.push(makeApp(cls, false));
        }
        out.push({ key: "settings", label: "Settings", icon: "settings", tile: "#FF8A5C", ids: [], system: true });
        return out;
    }
    readonly property int appCount: apps.length - 1

    function windowsOf(ids) {
        const out = [];
        const tl = ToplevelManager.toplevels.values;
        for (let i = 0; i < tl.length; i++)
            if (ids.indexOf(tl[i].appId) >= 0) out.push(tl[i]);
        return out;
    }
    readonly property string activeId: ToplevelManager.activeToplevel?.activated ? (ToplevelManager.activeToplevel.appId ?? "") : ""

    function launch(app) {
        if (app.system) { if (Ui.settingsOpen) Ui.settingsOpen = false; else Ui.openSettings(""); return; }
        if (app.launcher) { Ui.toggleLauncher(); return; }
        const hidden = Windows.minimizedOf(app.ids);
        if (hidden.length > 0) { Windows.restore(hidden[0]); return; }
        const open = windowsOf(app.ids);
        if (open.length > 0) { open[0].activate(); return; }
        newWindow(app);
    }
    function newWindow(app) {
        if (app.key === "islet-store") { Ui.storeOpen = true; return; }
        if (app.icon) Ui.announceLaunch(app.label, app.icon, app.tile);
        else Ui.announceLaunchUrl(app.label, app.iconUrl);
        // tra lại lúc bấm (phòng khi lúc dựng dock danh sách app chưa quét xong)
        const e = app.entry ?? entryFor(app.key) ?? app.ids.map(i => entryFor(i)).find(x => x) ?? null;
        if (e) Ui.launchEntry(e);
        else Quickshell.execDetached(["sh", "-c", app.key]);
    }

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
                    label: slot.modelData.label
                    icon: slot.modelData.icon
                    iconUrl: slot.modelData.iconUrl ?? ""
                    menuOpen: menu.open && menu.app?.key === slot.modelData.key
                    tile: slot.modelData.tile
                    order: slot.index
                    base: win.base
                    id: item
                    running: slot.modelData.system ? Ui.settingsOpen
                        : slot.modelData.launcher ? Ui.launcherOpen
                        : win.windowsOf(slot.modelData.ids).length > 0
                    minimized: !slot.modelData.system && !slot.modelData.launcher && running
                        && Windows.minimizedOf(slot.modelData.ids).length === win.windowsOf(slot.modelData.ids).length
                    focused: slot.modelData.system ? Ui.settingsOpen
                        : slot.modelData.launcher ? Ui.launcherOpen
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
        readonly property var app: win.apps[win.lastNearest]
        x: plate.x + lens.cx - width / 2
        anchors.bottom: plate.top
        anchors.bottomMargin: 8
        width: tagText.implicitWidth + 20
        height: 24
        radius: 12
        color: Qt.rgba(0.04, 0.04, 0.08, 0.88)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        opacity: lens.shown ? 1 : 0
        scale: lens.shown ? 1 : 0.85
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.005 } }
        Behavior on width { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.1 } }

        Text {
            id: tagText
            anchors.centerIn: parent
            text: tag.app.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
