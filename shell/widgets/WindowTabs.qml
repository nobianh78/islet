import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Ba chấm 🔴 đóng · 🟡 thu nhỏ · 🟢 phóng to cho từng cửa sổ, theo loại app:
//
//   "gtk"    App GTK/libadwaita tự vẽ ba chấm bên trong cửa sổ (theme/gtk/*.css).
//            Hyprland không hỗ trợ thu nhỏ nên GTK tắt nút 🟡 → Islet đặt một vùng bấm
//            vô hình đúng chỗ chấm vàng để thu nhỏ.
//   "inside" App không tự vẽ nút (kitty): Islet chừa lề trên trong app (kitty.conf) rồi vẽ
//            ba chấm + tên cửa sổ vào đó; cả dải trên cùng là chỗ kéo cửa sổ, như thanh tiêu đề.
//   "pill"   App lạ khác: viên kính nhỏ vắt ngang mép trên cửa sổ.
//
// Một lớp phủ kín màn hình (toạ độ trong lớp = toạ độ màn hình), chỉ các vùng trên nhận chuột.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false

    WlrLayershell.namespace: "islet-tabs"
    WlrLayershell.layer: WlrLayer.Top

    readonly property int barH: 44
    readonly property int stripH: 34       // dải trên cùng trong kitty (khớp lề trên trong kitty.conf)
    readonly property int pillH: 22
    readonly property int wsId: Hyprland.focusedWorkspace?.id ?? -1

    // Vị trí nút thu nhỏ do app tự vẽ, so với góc trên-trái cửa sổ (đo trên ảnh chụp).
    // App GTK/Firefox tắt / bỏ qua nút này vì Hyprland không hỗ trợ thu nhỏ → Islet bắt cú bấm thay.
    function minDotFor(cls) {
        if (cls === "firefox") return Qt.point(44, 23);   // theo theme/firefox/userChrome.css
        return Qt.point(40.5, 22.5);   // libadwaita
    }

    readonly property var insideApps: ["kitty", "foot", "Alacritty", "org.wezfurlong.wezterm"]
    readonly property var ownButtonsApps: ["chromium", "google-chrome", "code", "org.quickshell"]   // org.quickshell = Cài đặt của Islet (tự vẽ ba nút)

    function styleOf(cls) {
        if (insideApps.indexOf(cls) >= 0) return "inside";
        if (cls.startsWith("org.gnome.") || cls.startsWith("io.github.") || cls === "nautilus" || cls === "firefox") return "gtk";
        if (ownButtonsApps.indexOf(cls) >= 0) return "none";
        return "pill";
    }

    // Hyprland không báo vị trí cửa sổ theo thời gian thực → hỏi lại 30 lần/giây.
    Timer {
        interval: 33
        repeat: true
        running: rep.count > 0
        onTriggered: Hyprland.refreshToplevels()
    }

    // Vùng nhận chuột: tối đa 12 cửa sổ.
    function hitAt(i, n) { return i < n ? (rep.itemAt(i)?.hit ?? null) : null; }
    mask: Region {
        Region { item: win.hitAt(0, rep.count) }
        Region { item: win.hitAt(1, rep.count) }
        Region { item: win.hitAt(2, rep.count) }
        Region { item: win.hitAt(3, rep.count) }
        Region { item: win.hitAt(4, rep.count) }
        Region { item: win.hitAt(5, rep.count) }
        Region { item: win.hitAt(6, rep.count) }
        Region { item: win.hitAt(7, rep.count) }
        Region { item: win.hitAt(8, rep.count) }
        Region { item: win.hitAt(9, rep.count) }
        Region { item: win.hitAt(10, rep.count) }
        Region { item: win.hitAt(11, rep.count) }
    }

    // Cho thanh trên biết cửa sổ đang chọn đã có ba chấm riêng hay chưa.
    function syncActive() {
        let has = false;
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i);
            if (it && it.isActive && it.hasDots) has = true;
        }
        Ui.activeHasTab = has;
    }
    Timer { interval: 60; repeat: true; running: true; onTriggered: win.syncActive() }

    Repeater {
        id: rep
        model: Hyprland.toplevels

        Item {
            id: w
            required property var modelData
            readonly property var t: modelData
            readonly property var o: t.lastIpcObject ?? ({})
            readonly property string style: win.styleOf(o.class ?? "")

            // Hình học cửa sổ (toạ độ màn hình này); đang kéo thì theo con trỏ.
            property bool dragging: false
            property real dragX: 0
            property real dragY: 0
            readonly property real wx: dragging ? dragX : (o.at?.[0] ?? 0) - (win.screen?.x ?? 0)
            readonly property real wy: dragging ? dragY : (o.at?.[1] ?? 0) - (win.screen?.y ?? 0)
            readonly property real ww: o.size?.[0] ?? 0
            readonly property real wh: o.size?.[1] ?? 0
            readonly property int order: o.focusHistoryID ?? 99
            readonly property bool isActive: order === 0
            readonly property bool maximized: (o.fullscreen ?? 0) === 1

            readonly property bool onScreen: (o.workspace?.id ?? -2) === win.wsId && o.mapped !== false
                && !(o.hidden ?? false) && (o.fullscreen ?? 0) !== 2 && ww > 80

            // Vùng của mình có bị cửa sổ khác (nằm trên) che không?
            function coveredAt(rx, ry, rw, rh) {
                const list = Hyprland.toplevels.values;
                for (let i = 0; i < list.length; i++) {
                    const u = list[i].lastIpcObject;
                    if (!u || !u.at || u.address === o.address || (u.focusHistoryID ?? 99) >= order) continue;
                    if ((u.workspace?.id ?? -2) !== (o.workspace?.id ?? -3) || u.hidden) continue;
                    const ux = u.at[0] - (win.screen?.x ?? 0), uy = u.at[1] - (win.screen?.y ?? 0);
                    if (rx < ux + u.size[0] && rx + rw > ux && ry < uy + u.size[1] && ry + rh > uy) return true;
                }
                return false;
            }

            // ---- Vùng tương tác theo kiểu ----
            readonly property rect area: {
                if (style === "inside") return Qt.rect(wx, wy, ww, win.stripH);
                if (style === "gtk") {
                    const d = win.minDotFor(o.class ?? "");
                    return Qt.rect(wx + d.x - 11, wy + d.y - 11, 22, 22);
                }
                if (style === "pill") return Qt.rect(wx + 18, wy - win.pillH / 2, pill.width, win.pillH);
                return Qt.rect(0, 0, 0, 0);
            }
            readonly property bool pillRoom: wy - win.pillH / 2 >= win.barH + 2
            readonly property bool active: onScreen && style !== "none"
                && (style !== "pill" || pillRoom)
                && !coveredAt(area.x, area.y, area.width, area.height)
            readonly property bool hasDots: active || (onScreen && (style === "gtk" || style === "none"))

            property alias hit: hitbox
            Item {
                id: hitbox
                x: w.area.x
                y: w.area.y
                width: w.active ? w.area.width : 0
                height: w.active ? w.area.height : 0
            }

            // ---- Kéo cửa sổ (dùng chung cho "inside" và "pill") ----
            function beginDrag(gx, gy) {
                Windows.focusWin(t);
                drag.sx = gx; drag.sy = gy;
                drag.ox = wx; drag.oy = wy;
            }
            function moveDrag(gx, gy) {
                if (!dragging && Math.abs(gx - drag.sx) + Math.abs(gy - drag.sy) < 4) return;
                dragX = drag.ox + (gx - drag.sx);
                dragY = Math.max(win.barH + 4, drag.oy + (gy - drag.sy));
                dragging = true;
                drag.pending = true;
            }
            function endDrag() {
                if (dragging) {
                    Windows.moveWin(t, dragX + (win.screen?.x ?? 0), dragY + (win.screen?.y ?? 0));
                    settle.restart();
                }
                drag.pending = false;
            }
            QtObject {
                id: drag
                property real sx: 0
                property real sy: 0
                property real ox: 0
                property real oy: 0
                property bool pending: false
            }
            // Gửi vị trí mới cho Hyprland tối đa ~60 lần/giây.
            Timer {
                interval: 16
                repeat: true
                running: w.dragging
                onTriggered: if (drag.pending) {
                    drag.pending = false;
                    Windows.moveWin(w.t, w.dragX + (win.screen?.x ?? 0), w.dragY + (win.screen?.y ?? 0));
                }
            }
            // Thả tay rồi đợi Hyprland báo vị trí mới mới thôi bám theo con trỏ.
            Timer { id: settle; interval: 90; onTriggered: w.dragging = false }

            // ================= "inside": thanh tiêu đề bên trong kitty =================
            Item {
                id: strip
                visible: w.style === "inside" && w.active
                x: w.wx
                y: w.wy
                width: w.ww
                height: win.stripH

                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    onPressed: m => w.beginDrag(m.x + strip.x, m.y + strip.y)
                    onPositionChanged: m => { if (pressed) w.moveDrag(m.x + strip.x, m.y + strip.y); }
                    onReleased: w.endDrag()
                    onDoubleClicked: Windows.maximizeWin(w.t)
                }

                TrafficLights {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    lit: w.isActive
                    maximized: w.maximized
                    onCloseClicked: Windows.closeWin(w.t)
                    onMinimizeClicked: Windows.minimizeWin(w.t)
                    onMaximizeClicked: Windows.maximizeWin(w.t)
                }

                Text {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 180)
                    horizontalAlignment: Text.AlignHCenter
                    text: w.o.title || Windows.nameOf(w.t)
                    color: w.isActive ? Theme.textDim : Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideMiddle
                }
            }

            // ================= "gtk": vùng bấm vô hình trên chấm vàng =================
            MouseArea {
                visible: w.style === "gtk" && w.active
                x: w.area.x
                y: w.area.y
                width: w.area.width
                height: w.area.height
                cursorShape: Qt.PointingHandCursor
                onClicked: Windows.minimizeWin(w.t)
            }

            // ================= "pill": viên kính vắt ngang mép trên =================
            Item {
                id: pill
                visible: w.style === "pill" && opacity > 0.01
                x: w.wx + 18
                y: w.wy - win.pillH / 2
                width: pillLights.implicitWidth + 20
                height: win.pillH
                opacity: w.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                scale: pillLights.hovered || pillDrag.containsMouse ? 1.08 : 1
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.003 } }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(0.027, 0.027, 0.06, w.isActive ? 0.9 : 0.7)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, w.isActive ? 0.18 : 0.10)
                }
                MouseArea {
                    id: pillDrag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: m => w.beginDrag(m.x + pill.x, m.y + pill.y)
                    onPositionChanged: m => { if (pressed) w.moveDrag(m.x + pill.x, m.y + pill.y); }
                    onReleased: w.endDrag()
                    onDoubleClicked: Windows.maximizeWin(w.t)
                }
                TrafficLights {
                    id: pillLights
                    anchors.centerIn: parent
                    lit: w.isActive
                    maximized: w.maximized
                    onCloseClicked: Windows.closeWin(w.t)
                    onMinimizeClicked: Windows.minimizeWin(w.t)
                    onMaximizeClicked: Windows.maximizeWin(w.t)
                }
            }
        }
    }
}
