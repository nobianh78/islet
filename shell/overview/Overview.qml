import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"
import "../wallpaper"

// Overview (Mission Control) — Super+Tab, vuốt 3 ngón lên, chụm 4 ngón.
//   · cửa sổ của workspace đang xem bay từ chỗ thật ra lưới, ảnh xem trước trực tiếp (ScreencopyView)
//   · bấm = chọn cửa sổ · rê → nút × đóng · kéo thả lên dải workspace = chuyển sang workspace đó
//   · bấm một workspace ở dải trên = xem cửa sổ của workspace đó · Esc / bấm chỗ trống = đóng
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "islet-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool shown: false
    visible: shown || anim.t > 0.001
    property int viewWs: 1
    property var wins: []                 // HyprlandToplevel đang bày
    property string picked: ""            // address cửa sổ được chọn khi đóng

    function open() {
        if (shown) return;
        Hyprland.refreshToplevels();
        viewWs = Hyprland.focusedWorkspace?.id ?? 1;
        collect();
        picked = "";
        shown = true;
        anim.to(1);
        keys.forceActiveFocus();
    }
    function close(addr) {
        if (!shown) return;
        picked = addr || "";
        if (picked) {
            const t = wins.find(w => w.address === picked || ("0x" + w.address) === picked);
            if (t && Windows.isMinimized(t)) Windows.restore(t); else if (t) Windows.focusWin(t);
        }
        shown = false;
        anim.to(0);
    }
    function toggle() { if (shown) close(""); else open(); }
    function collect() {
        const all = Hyprland.toplevels.values;
        const here = all.filter(t => t.workspace?.id === viewWs);
        const mini = all.filter(t => Windows.isMinimized(t));
        wins = here.concat(mini);
    }
    function showWs(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        viewWs = id;
        refreshLater.restart();
    }
    Timer { id: refreshLater; interval: 120; onTriggered: { Hyprland.refreshToplevels(); win.collect(); } }
    function moveTo(t, id) {
        Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + id + ', follow = false, window = "' + Windows.addr(t) + '" })');
        refreshLater.restart();
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { win.toggle(); }
        function open(): void { win.open(); }
        function close(): void { win.close(""); }
    }

    // tiến trình chung của hiệu ứng mở (0 = cửa sổ ở chỗ thật, 1 = trong lưới)
    QtObject {
        id: anim
        property real t: 0
        function to(v) { na.to = v; na.restart(); }
    }
    NumberAnimation { id: na; target: anim; property: "t"; duration: 420; easing.type: Easing.OutCubic }

    // ---------------- bố cục lưới ----------------
    readonly property real topBand: 150
    readonly property real gap: 28
    readonly property var layout: {
        const n = wins.length;
        if (n === 0) return [];
        const W = width - 2 * gap, H = height - topBand - 70;
        let best = null;
        for (let c = 1; c <= n; c++) {
            const r = Math.ceil(n / c);
            const cw = (W - (c - 1) * gap) / c, ch = (H - (r - 1) * gap) / r - 30;
            let s = 1;
            for (const t of wins) {
                const o = t.lastIpcObject || {};
                const w = o.size?.[0] || 800, h = o.size?.[1] || 600;
                s = Math.min(s, cw / w, ch / h);
            }
            if (!best || s > best.s) best = { c: c, r: r, cw: cw, ch: ch, s: s };
        }
        const out = [];
        const totalH = best.r * (best.ch + 30) + (best.r - 1) * gap;
        const y0 = topBand + (H - totalH) / 2;
        for (let i = 0; i < n; i++) {
            const o = wins[i].lastIpcObject || {};
            const w = (o.size?.[0] || 800) * best.s, h = (o.size?.[1] || 600) * best.s;
            const row = Math.floor(i / best.c), col = i % best.c;
            const inRow = Math.min(best.c, n - row * best.c);
            const rowW = inRow * best.cw + (inRow - 1) * gap;
            const x0 = gap + (W - rowW) / 2 + col * (best.cw + gap) + (best.cw - w) / 2;
            out.push({ x: x0, y: y0 + row * (best.ch + 30 + gap) + (best.ch - h) / 2, w: w, h: h });
        }
        return out;
    }

    // ---------------- nền ----------------
    Item {
        anchors.fill: parent
        opacity: anim.t
        Backdrop {
            anchors.fill: parent
            animated: false
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 0.8; brightness: -0.18 }
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.25) }
        MouseArea { anchors.fill: parent; onClicked: win.close("") }
    }

    Item {
        id: keys
        focus: win.shown
        Keys.onEscapePressed: win.close("")
        Keys.onReturnPressed: if (win.wins.length) win.close(win.wins[0].address)
    }

    // ---------------- dải workspace ----------------
    Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52 - 30 * (1 - anim.t)
        opacity: anim.t
        spacing: 12
        readonly property int maxWs: Math.max(4, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id + 1))
        Repeater {
            model: strip.maxWs
            Rectangle {
                id: wsPill
                required property int index
                readonly property int wsId: index + 1
                readonly property int count: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId).length
                readonly property bool here: win.viewWs === wsId
                property bool dropHot: false
                width: 132; height: 78; radius: 16
                color: dropHot ? Theme.tint(0.4) : here ? Theme.tint(0.22) : wm.containsMouse ? Theme.fg(0.14) : Theme.fg(0.07)
                border.width: here || dropHot ? 2 : 1
                border.color: here || dropHot ? Theme.accent : Theme.fg(0.1)
                Behavior on color { ColorAnimation { duration: 140 } }
                scale: dropHot ? 1.06 : 1
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.35 } }
                // mini xem trước: mỗi cửa sổ một ô nhỏ
                Flow {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    spacing: 4
                    Repeater {
                        model: Math.min(wsPill.count, 6)
                        Rectangle { width: 30; height: 18; radius: 4; color: Theme.fg(0.22) }
                    }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    text: wsPill.count === 0 ? "Desktop " + wsPill.wsId + " · empty" : "Desktop " + wsPill.wsId
                    color: wsPill.here ? Theme.label : Theme.subtle
                    font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold
                }
                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.showWs(wsPill.wsId) }
            }
        }
    }
    function pillAt(gx, gy) {
        for (let i = 0; i < strip.children.length; i++) {
            const p = strip.children[i];
            if (p.wsId === undefined) continue;
            const q = p.mapFromItem(null, gx, gy);
            if (q.x >= 0 && q.y >= 0 && q.x <= p.width && q.y <= p.height) return p;
        }
        return null;
    }

    Text {
        visible: win.wins.length === 0
        anchors.centerIn: parent
        opacity: anim.t * 0.8
        text: "No windows on this desktop"
        color: Theme.label; font.family: Theme.font; font.pixelSize: 16
    }

    // ---------------- cửa sổ ----------------
    Repeater {
        model: win.wins
        Item {
            id: card
            required property var modelData
            required property int index
            readonly property var o: modelData.lastIpcObject || {}
            readonly property var g: win.layout[index] || { x: 0, y: 0, w: 100, h: 80 }
            readonly property bool mini: Windows.isMinimized(modelData)
            // chỗ thật của cửa sổ (toạ độ màn hình); cửa sổ thu nhỏ thì bay lên từ dock
            readonly property real rx: mini ? win.width / 2 - 60 : (o.at?.[0] ?? 0) - (win.screen?.x ?? 0)
            readonly property real ry: mini ? win.height - 60 : (o.at?.[1] ?? 0) - (win.screen?.y ?? 0)
            readonly property real rw: mini ? 120 : (o.size?.[0] ?? 400)
            readonly property real rh: mini ? 80 : (o.size?.[1] ?? 300)
            property real dx: 0
            property real dy: 0
            readonly property real t: card.modelData.address === win.picked ? anim.t : anim.t
            x: rx + (g.x - rx) * t + dx
            y: ry + (g.y - ry) * t + dy
            width: rw + (g.w - rw) * t
            height: rh + (g.h - rh) * t
            z: drag.active ? 10 : 1
            opacity: mini ? 0.55 + 0.45 * (hov.hovered ? 1 : 0) : 1

            HoverHandler { id: hov }
            Rounded {
                id: shot
                anchors.fill: parent
                radius: 14 * card.t + 6
                scale: hov.hovered && !drag.active ? 1.025 : 1
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.002 } }
                Rectangle { anchors.fill: parent; color: Qt.rgba(0.1, 0.1, 0.14, 1) }
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: win.visible ? card.modelData.wayland : null
                    live: win.shown
                    paintCursor: false
                }
            }
            Rectangle {
                anchors.fill: shot
                radius: shot.radius
                color: "transparent"
                border.width: hov.hovered ? 3 : 1
                border.color: hov.hovered ? Theme.accent : Theme.fg(0.12)
                scale: shot.scale
            }
            // tên cửa sổ
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8
                spacing: 6
                opacity: card.t
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    name: Theme.appKey(card.o.class ?? "")
                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(card.o.class ?? "")?.icon ?? (card.o.class ?? ""), true)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, card.width - 30)
                    elide: Text.ElideRight
                    text: (card.mini ? "Minimized · " : "") + (card.modelData.title || card.o.class || "")
                    color: Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                }
            }
            // ×
            Rectangle {
                visible: hov.hovered && !drag.active && card.t > 0.9
                x: -10; y: -10
                width: 26; height: 26; radius: 13
                color: xm.containsMouse ? "#FF5F57" : Qt.rgba(0.15, 0.15, 0.18, 0.95)
                border.width: 1; border.color: Theme.fg(0.2)
                TIcon { anchors.centerIn: parent; name: "close"; size: 12 }
                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Windows.closeWin(card.modelData); refreshLater.restart(); } }
            }

            TapHandler { onTapped: win.close(card.modelData.address) }
            DragHandler {
                id: drag
                target: null
                property real sx: 0
                property real sy: 0
                onActiveChanged: {
                    if (active) return;
                    const c = centroid.scenePosition;
                    const p = win.pillAt(c.x, c.y);
                    for (let i = 0; i < strip.children.length; i++) if (strip.children[i].dropHot !== undefined) strip.children[i].dropHot = false;
                    card.dx = 0; card.dy = 0;
                    if (p && p.wsId !== win.viewWs) win.moveTo(card.modelData, p.wsId);
                }
                onTranslationChanged: {
                    card.dx = translation.x; card.dy = translation.y;
                    const c = centroid.scenePosition, p = win.pillAt(c.x, c.y);
                    for (let i = 0; i < strip.children.length; i++) if (strip.children[i].dropHot !== undefined) strip.children[i].dropHot = strip.children[i] === p;
                }
            }
        }
    }
}
