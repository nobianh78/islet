import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Màn hình nền: widget (đồng hồ, lịch, thời tiết, CPU & bộ nhớ) và ghi chú dán.
// Nằm ngay trên hình nền, dưới mọi cửa sổ. Kéo để dời chỗ; bấm chuột phải lên màn hình nền để
// thêm ghi chú hay bật/tắt widget. Chỉ ở màn hình chính.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Prefs.desktopWidgets && !Ui.locked

    WlrLayershell.namespace: "islet-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    // gõ được vào ghi chú: lớp này chỉ nhận bàn phím khi bấm vào nó
    WlrLayershell.keyboardFocus: DesktopItems.notes.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property int top: 56                 // dưới thanh trên + island
    readonly property int gap: 16

    // chỗ mặc định: cột bên phải, xếp từ trên xuống theo thứ tự các loại widget; hết chỗ (chừa dock)
    // thì sang cột bên trái kế đó
    readonly property int bottomLimit: win.height - 100
    function autoPos(id) {
        let x = win.width - 28, y = top, colW = 0;
        for (const k of DesktopItems.kinds) {
            const w = DesktopItems.widget(k.id);
            if (!(w.on && w.x < 0) && k.id !== id) continue;
            if (y > top && y + k.h > bottomLimit) { x -= colW + gap; y = top; colW = 0; }
            if (k.id === id) return Qt.point(x - k.w, y);
            y += k.h + gap;
            colW = Math.max(colW, k.w);
        }
        return Qt.point(win.width - 328, top);
    }

    // ---------- bấm chuột phải lên màn hình nền ----------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: m => {
            menu.close();
            win.contentItem.forceActiveFocus();          // bỏ con trỏ gõ khỏi ghi chú
            if (m.button === Qt.RightButton) menu.openAt(m.x, m.y);
        }
    }

    // ---------- widget ----------
    Repeater {
        model: DesktopItems.kinds
        DesktopWidget {
            id: dw
            required property var modelData
            readonly property var st: DesktopItems.widget(modelData.id)
            visible: st.on
            kind: modelData.id
            width: modelData.w; height: modelData.h
            x: st.x >= 0 ? Math.min(st.x, win.width - width) : win.autoPos(modelData.id).x
            y: st.y >= 0 ? Math.min(st.y, win.height - height) : win.autoPos(modelData.id).y
            onMoved: (nx, ny) => DesktopItems.setWidget(modelData.id, { x: Math.round(nx), y: Math.round(ny) })
            onRemoveRequested: DesktopItems.setWidget(modelData.id, { on: false })
        }
    }

    // ---------- ghi chú dán ----------
    Repeater {
        model: DesktopItems.noteModel
        StickyNote {
            required property string nid
            noteId: nid
            area: Qt.size(win.width, win.height)
        }
    }

    // ---------- menu chuột phải ----------
    Rectangle {
        id: menu
        visible: false
        z: 100
        width: 220
        height: mcol.implicitHeight + 12
        radius: 14
        color: Qt.rgba(0.11, 0.11, 0.15, 0.96)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        property point at: Qt.point(0, 0)
        function openAt(px, py) {
            at = Qt.point(px, py);
            x = Math.min(px, win.width - width - 8);
            y = Math.min(py, win.height - height - 8);
            visible = true;
        }
        function close() { visible = false; }
        Column {
            id: mcol
            x: 6; y: 6; width: parent.width - 12
            MenuRow { icon: "note"; label: "New sticky note"; onClicked: { menu.close(); DesktopItems.focusNote(DesktopItems.addNote(menu.at.x, menu.at.y)); } }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            Repeater {
                model: DesktopItems.kinds
                MenuRow {
                    required property var modelData
                    icon: DesktopItems.widget(modelData.id).on ? "check" : "dot"
                    dim: !DesktopItems.widget(modelData.id).on
                    label: modelData.label
                    onClicked: DesktopItems.toggle(modelData.id)
                }
            }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            MenuRow { icon: "image"; label: "Change wallpaper…"; onClicked: { menu.close(); Ui.openSettings("wallpaper"); } }
            MenuRow { icon: "settings"; label: "Desktop settings…"; onClicked: { menu.close(); Ui.openSettings("island"); } }
        }
    }

    component MenuRow: Rectangle {
        id: mr
        property string icon: ""
        property string label: ""
        property bool dim: false
        signal clicked()
        width: parent ? parent.width : 200
        height: 34; radius: 9
        color: mra.containsMouse ? Theme.tint(0.3) : "transparent"
        Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: mr.icon; size: 15; opacity: mr.dim ? 0.35 : 0.9 }
        Text { x: 36; anchors.verticalCenter: parent.verticalCenter; text: mr.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        MouseArea { id: mra; anchors.fill: parent; hoverEnabled: true; onClicked: mr.clicked() }
    }
}
