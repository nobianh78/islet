import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Màn hình nền: widget, ghi chú dán và icon của những gì nằm trong ~/Desktop.
// Nằm ngay trên hình nền, dưới mọi cửa sổ. Bấm chuột phải để thêm widget / ghi chú / thư mục.
// Chỉ ở màn hình chính.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Prefs.desktopWidgets && !Ui.locked

    WlrLayershell.namespace: "islet-desktop"
    WlrLayershell.layer: WlrLayer.Bottom
    // gõ được vào ghi chú / đổi tên file: lớp này chỉ nhận bàn phím khi bấm vào nó
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property int top: 56                 // dưới thanh trên + island
    readonly property int gap: 16
    readonly property int bottomLimit: win.height - 100

    // chỗ mặc định của widget: cột bên phải, xếp từ trên xuống; hết chỗ thì sang cột bên trái kế đó
    function autoPos(uid) {
        let x = win.width - 28, y = top, colW = 0;
        for (const w of DesktopItems.widgets) {
            const k = DesktopItems.kind(w.kind);
            if (!k) continue;
            if (w.x >= 0 && w.uid !== uid) continue;
            if (y > top && y + k.h > bottomLimit) { x -= colW + gap; y = top; colW = 0; }
            if (w.uid === uid) return Qt.point(x - k.w, y);
            y += k.h + gap;
            colW = Math.max(colW, k.w);
        }
        return Qt.point(win.width - 328, top);
    }

    // ---------- bấm vào nền ----------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: m => {
            menu.close();
            icons.clearSelection();
            icons.openStack = null;
            win.contentItem.forceActiveFocus();          // bỏ con trỏ gõ khỏi ghi chú
            if (m.button === Qt.RightButton) menu.openAt(m.x, m.y);
        }
    }

    // ---------- thả file vào màn hình nền ----------
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: e => {
            const files = e.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(x => x.startsWith("/"));
            DesktopFiles.drop(files);
            e.acceptProposedAction();
        }
    }

    // ---------- file trong ~/Desktop ----------
    DesktopIcons { id: icons; anchors.fill: parent; topY: win.top }

    // ---------- widget ----------
    Repeater {
        model: DesktopItems.widgetModel
        DesktopWidget {
            id: dw
            required property string wid
            uid: wid
            readonly property point auto_: win.autoPos(dw.uid)
            x: (st?.x ?? -1) >= 0 ? Math.min(st.x, win.width - width) : auto_.x
            y: (st?.y ?? -1) >= 0 ? Math.min(st.y, win.height - height) : auto_.y
            onMoved: (nx, ny) => DesktopItems.setWidget(dw.uid, { x: Math.round(nx), y: Math.round(ny) })
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
        width: 230
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
            MenuRow { icon: "grid"; label: "Widgets…"; onClicked: { menu.close(); Ui.openWidgets(); } }
            MenuRow { icon: "note"; label: "New sticky note"; onClicked: { menu.close(); DesktopItems.focusNote(DesktopItems.addNote(menu.at.x, menu.at.y)); } }
            MenuRow { icon: "folder"; label: "New folder"; onClicked: { menu.close(); DesktopFiles.newFolder(null); } }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            MenuRow {
                icon: DesktopItems.stacks ? "check" : "dot"
                dim: !DesktopItems.stacks
                label: "Group files into stacks"
                onClicked: { DesktopItems.setStacks(!DesktopItems.stacks); menu.close(); }
            }
            MenuRow { icon: "refresh"; label: "Tidy up"; onClicked: { menu.close(); DesktopItems.tidyFiles(); DesktopItems.resetPositions(); } }
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
