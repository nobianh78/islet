import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Icon của file, thư mục và lối tắt trong ~/Desktop.
//   · bấm đúp để mở · kéo để dời chỗ (nhớ vị trí)
//   · kéo icon này thả lên icon kia = gom vào MỘT KHUNG ngay trên màn hình nền (như gom app trên
//     điện thoại — file vẫn nằm nguyên trong ~/Desktop); thả lên thư mục thật = bỏ vào trong thư mục
//   · bấm chọn rồi Space = xem nhanh (Quick Look), Enter = mở
//   · chuột phải: mở · xem nhanh · đổi tên · thư mục mới · bỏ vào thùng rác
//   · chế độ Stacks: gom theo loại thành từng chồng, bấm vào để xem bên trong
Item {
    id: root
    property int topY: 56
    readonly property int cellW: 96
    readonly property int cellH: 104
    readonly property int pad: 18

    property string selected: ""
    property string renaming: ""
    property string dropTarget: ""          // tên mục đang bị kéo đè lên
    property string dragging: ""
    property var openStack: null            // chồng đang mở (chế độ Stacks)

    readonly property bool stacks: DesktopItems.stacks
    readonly property var all: DesktopFiles.items
    readonly property var groups: DesktopItems.groups
    // file đã nằm trong một khung thì không hiện rời nữa
    readonly property var items: all.filter(i => !DesktopItems.inAnyGroup(i.name))
    function membersOf(g) { return (g.items ?? []).map(n => all.find(i => i.name === n)).filter(x => x); }
    property string openGroup: ""

    // file bị xoá / đổi tên ở nơi khác → dọn khỏi khung
    onAllChanged: DesktopItems.pruneGroups(all.map(i => i.name))

    // ---- chồng theo loại (Stacks) ----
    readonly property var piles: {
        if (!stacks) return [];
        const by = {};
        for (const it of items) (by[it.kind] = by[it.kind] || []).push(it);
        return DesktopFiles.kindOrder.filter(k => by[k]).map(k => ({ kind: k, label: DesktopFiles.kindLabels[k], items: by[k] }));
    }

    readonly property int rows: Math.max(1, Math.floor((root.height - topY - 110) / cellH))
    function rawCell(i) { return Qt.point(pad + Math.floor(i / rows) * cellW, topY + (i % rows) * cellH); }
    function cellIndexAt(x, y) {
        const c = Math.round((x - pad) / cellW), r = Math.round((y - topY) / cellH);
        return (c < 0 || r < 0 || r >= rows) ? -1 : c * rows + r;
    }
    // ô đã có khung hoặc icon được đặt tay → icon tự xếp phải tránh ra
    readonly property var taken: {
        const t = {};
        for (const g of root.groups) { const i = cellIndexAt(g.x, g.y); if (i >= 0) t[i] = true; }
        const f = DesktopItems.files;
        for (const n in f) { const i = cellIndexAt(f[n].x, f[n].y); if (i >= 0) t[i] = true; }
        return t;
    }
    // ô trống thứ i
    function cellAt(i) {
        let n = -1;
        for (let c = 0; c < rows * 24; c++) {
            if (taken[c]) continue;
            if (++n === i) return rawCell(c);
        }
        return rawCell(i);
    }
    // vị trí của một mục: đã đặt tay thì theo đó, chưa thì xếp lưới theo thứ tự
    function posOf(name, autoIndex) {
        const p = DesktopItems.filePos(name);
        if (p) return Qt.point(Math.max(0, Math.min(p.x, root.width - cellW)), Math.max(0, Math.min(p.y, root.height - cellH)));
        return cellAt(autoIndex);
    }
    function autoIndexOf(name) {
        let n = 0;
        for (const it of items) {
            if (it.name === name) return n;
            if (!DesktopItems.filePos(it.name)) n++;
        }
        return n;
    }
    property string groupSel: ""            // mục đang chọn bên trong khung đang mở
    function clearSelection() { selected = ""; renaming = ""; groupSel = ""; openGroup = ""; groupMenu.close(); }

    // ---- bàn phím: Space = xem nhanh · Enter = mở · Esc = đóng khung ----
    function current() {
        if (openGroup && groupSel) return all.find(i => i.name === groupSel) ?? null;
        if (openGroup) { const g = DesktopItems.group(openGroup); return g ? (all.find(i => i.name === g.items[0]) ?? null) : null; }
        return all.find(i => i.name === selected) ?? null;
    }
    function look() { const it = current(); if (it) QuickLook.show(it.path); }
    function openCurrent() { const it = current(); if (it) DesktopFiles.open(it.path); }
    function grabKeys() { keys.forceActiveFocus(); }
    Item {
        id: keys
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Space) { root.look(); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.openCurrent(); e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { root.openGroup = ""; root.groupSel = ""; root.selected = ""; e.accepted = true; }
        }
    }

    // tên gợi ý cho khung mới: cùng loại thì lấy tên loại, khác loại thì "Group"
    function nameFor(a, b) {
        return a.kind === b.kind ? (DesktopFiles.kindLabels[a.kind] ?? "Group") : "Group";
    }
    // thả icon lên icon khác: gom vào một khung · thả lên thư mục thật: bỏ vào trong thư mục
    function dropOn(src, dstName) {
        const from = all.find(i => i.name === src);
        if (!from) return;
        if (dstName.startsWith("g:")) { DesktopItems.joinGroup(dstName.slice(2), src); return; }
        const dst = all.find(i => i.name === dstName);
        if (!dst || dst.name === from.name) return;
        if (dst.dir) { DesktopFiles.run(["group", dst.name, from.path], null); DesktopItems.clearFilePos(from.name); return; }
        const at = root.posOf(dst.name, root.autoIndexOf(dst.name));        // khung đứng đúng chỗ icon bị thả lên
        DesktopItems.makeGroup([dst.name, from.name], at.x, at.y, nameFor(dst, from));
    }
    // mục đang bị kéo đè lên (icon rời hoặc khung) — khung ghi là "g:<gid>"
    function hitAt(gx, gy, selfName) {
        for (const g of root.groups) {
            if (("g:" + g.gid) === selfName) continue;
            if (gx > g.x && gx < g.x + cellW && gy > g.y && gy < g.y + cellH) return "g:" + g.gid;
        }
        for (const it of root.items) {
            if (it.name === selfName) continue;
            const p = root.posOf(it.name, root.autoIndexOf(it.name));
            if (gx > p.x && gx < p.x + cellW && gy > p.y && gy < p.y + cellH) return it.name;
        }
        return "";
    }

    // ================= icon rời =================
    Repeater {
        model: root.stacks ? [] : root.items
        DesktopIcon {
            required property var modelData
            item: modelData
            area: Qt.size(root.width, root.height)
            selected: root.selected === modelData.name
            renaming: root.renaming === modelData.name
            dropHover: root.dropTarget === modelData.name
            home: root.posOf(modelData.name, root.autoIndexOf(modelData.name))
            onPicked: { root.selected = modelData.name; root.renaming = ""; root.groupSel = ""; root.grabKeys(); }
            onOpenRequested: DesktopFiles.open(modelData.path)
            onRenamed: n => { root.renaming = ""; if (n && n !== modelData.name) DesktopFiles.rename(modelData.path, n); }
            onMenuRequested: (gx, gy) => { root.selected = modelData.name; iconMenu.openAt(gx, gy, modelData); }
            onDragStarted: root.dragging = modelData.name
            onDragMoved: (gx, gy) => root.dropTarget = root.hitAt(gx, gy, modelData.name)
            onDragEnded: (nx, ny) => {
                const t = root.dropTarget;
                root.dropTarget = ""; root.dragging = "";
                if (t) root.dropOn(modelData.name, t);
                else DesktopItems.setFilePos(modelData.name, nx, ny);
            }
        }
    }

    // ================= khung gom (như gom app trên điện thoại) =================
    Repeater {
        model: root.groups
        DesktopGroup {
            required property var modelData
            group: modelData
            members: root.membersOf(modelData)
            area: Qt.size(root.width, root.height)
            open: root.openGroup === modelData.gid
            dropHover: root.dropTarget === ("g:" + modelData.gid)
            onPicked: { root.selected = ""; root.renaming = ""; root.grabKeys(); }
            onOpenRequested: { root.groupSel = ""; root.openGroup = root.openGroup === modelData.gid ? "" : modelData.gid; root.grabKeys(); }
            onMenuRequested: (gx, gy) => groupMenu.openAt(gx, gy, modelData)
            onDragStarted: { root.dragging = "g:" + modelData.gid; root.openGroup = ""; }
            onDragMoved: (gx, gy) => root.dropTarget = root.hitAt(gx, gy, "g:" + modelData.gid)
            onDragEnded: (nx, ny) => {
                const t = root.dropTarget;
                root.dropTarget = ""; root.dragging = "";
                if (t && !t.startsWith("g:")) DesktopItems.joinGroup(modelData.gid, t);     // thả khung lên một file = hút file vào khung
                else DesktopItems.setGroup(modelData.gid, { x: Math.round(nx), y: Math.round(ny) });
            }
        }
    }

    // ---- mở một khung ----
    Rectangle {
        id: groupPop
        readonly property var g: root.groups.find(x => x.gid === root.openGroup) ?? null
        readonly property var list: g ? root.membersOf(g) : []
        visible: g !== null
        z: 150
        readonly property int cols: Math.min(4, Math.max(1, list.length))
        width: cols * root.cellW + 24
        height: Math.ceil(list.length / cols) * root.cellH + 56
        x: Math.max(8, Math.min((g?.x ?? 0) + root.cellW / 2 - width / 2, root.width - width - 8))
        y: Math.max(root.topY, Math.min((g?.y ?? 0) + root.cellH + 8, root.height - height - 20))
        radius: 22
        color: Qt.rgba(0.09, 0.09, 0.13, 0.99)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
        scale: visible ? 1 : 0.9
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.4 } }

        // tên khung — bấm để sửa
        Item {
            x: 16; y: 12; width: parent.width - 60; height: 24
            Text {
                id: gname
                visible: !gedit.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: groupPop.g?.name ?? ""
                color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                visible: !gedit.activeFocus
                cursorShape: Qt.IBeamCursor
                onClicked: { gedit.text = groupPop.g?.name ?? ""; gedit.forceActiveFocus(); gedit.selectAll(); }
            }
            Rectangle {
                visible: gedit.activeFocus
                anchors.fill: parent
                radius: 7
                color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1; border.color: Theme.accent
            }
            TextInput {
                id: gedit
                anchors.fill: parent; anchors.margins: 5
                visible: activeFocus
                color: "#FFFFFF"; selectionColor: Theme.accent
                font.family: Theme.font; font.pixelSize: 13
                onAccepted: { if (groupPop.g && text.trim()) DesktopItems.setGroup(groupPop.g.gid, { name: text.trim() }); focus = false; }
                Keys.onEscapePressed: focus = false
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 16; y: 16
            text: "Break up"; color: gbm.containsMouse ? "#FFFFFF" : "#8E8E93"
            font.family: Theme.font; font.pixelSize: 11
            MouseArea {
                id: gbm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { const id = groupPop.g.gid; root.openGroup = ""; DesktopItems.breakGroup(id); }
            }
        }

        Grid {
            x: 12; y: 44
            columns: groupPop.cols
            Repeater {
                model: groupPop.list
                Item {
                    id: gi
                    required property var modelData
                    width: root.cellW; height: root.cellH
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4; radius: 12
                        color: root.groupSel === gi.modelData.name ? Theme.tint(0.32) : gim.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10; width: 46; height: 46; sourceSize: Qt.size(92, 92)
                        source: gi.modelData.image ? "file://" + gi.modelData.image : Theme.icon(gi.modelData.icon)
                        fillMode: gi.modelData.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Text {
                        y: 62; x: 4; width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: gi.modelData.app || gi.modelData.name
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 10
                        elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                    }
                    // nhấc ra khỏi khung (nằm trên lớp bấm của cả ô)
                    Rectangle {
                        z: 2
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 6
                        width: 20; height: 20; radius: 10
                        visible: gim.containsMouse || outm.containsMouse
                        color: outm.containsMouse ? "#FF5F57" : Qt.rgba(0.2, 0.2, 0.25, 0.95)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
                        Icon { anchors.centerIn: parent; name: "expand"; size: 11 }
                        MouseArea {
                            id: outm
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const g = groupPop.g;
                                DesktopItems.leaveGroup(g.gid, gi.modelData.name, g.x + root.cellW, g.y);
                                if (DesktopItems.group(g.gid) === null) root.openGroup = "";
                            }
                        }
                    }
                    MouseArea {
                        id: gim
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { root.groupSel = gi.modelData.name; root.grabKeys(); }
                        onDoubleClicked: { DesktopFiles.open(gi.modelData.path); root.openGroup = ""; }
                    }
                }
            }
        }
    }

    // ---- menu chuột phải trên khung ----
    Rectangle {
        id: groupMenu
        visible: false
        z: 200
        width: 200
        height: gmcol.implicitHeight + 12
        radius: 14
        color: Qt.rgba(0.11, 0.11, 0.15, 0.96)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        property var g: null
        function openAt(px, py, g_) {
            g = g_;
            x = Math.min(px, root.width - width - 8);
            y = Math.min(py, root.height - height - 8);
            visible = true;
        }
        function close() { visible = false; }
        Column {
            id: gmcol
            x: 6; y: 6; width: parent.width - 12
            Row2 { icon: "grid"; label: "Open"; onClicked: { root.openGroup = groupMenu.g.gid; groupMenu.close(); } }
            Row2 { icon: "edit"; label: "Rename group"; onClicked: { root.openGroup = groupMenu.g.gid; groupMenu.close(); } }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            Row2 { icon: "minus"; label: "Break up"; onClicked: { const id = groupMenu.g.gid; groupMenu.close(); root.openGroup = ""; DesktopItems.breakGroup(id); } }
        }
    }

    // ================= chồng (Stacks) =================
    Repeater {
        model: root.stacks ? root.piles : []
        Item {
            id: pile
            required property var modelData
            required property int index
            readonly property point home: root.cellAt(index)
            x: home.x; y: home.y
            width: root.cellW; height: root.cellH
            // hai tấm lệch phía sau cho ra dáng "chồng"
            Repeater {
                model: Math.min(2, pile.modelData.items.length - 1)
                Rectangle {
                    required property int index
                    width: 54; height: 54; radius: 12
                    x: (root.cellW - 54) / 2 + (index + 1) * 3
                    y: 8 + (index + 1) * 3
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                }
            }
            Rectangle {
                width: 58; height: 58; radius: 14
                x: (root.cellW - 58) / 2; y: 6
                color: pm.containsMouse || root.openStack === pile.modelData.kind ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { ColorAnimation { duration: 130 } }
                Image {
                    anchors.centerIn: parent
                    width: 34; height: 34; sourceSize: Qt.size(68, 68)
                    source: pile.modelData.items[0]?.image ? "file://" + pile.modelData.items[0].image
                          : Theme.icon(pile.modelData.items[0]?.icon ?? "folder")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {
                y: 70; width: root.cellW; horizontalAlignment: Text.AlignHCenter
                text: pile.modelData.label + " (" + pile.modelData.items.length + ")"
                color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.55)
                elide: Text.ElideRight
            }
            MouseArea {
                id: pm
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.openStack = root.openStack === pile.modelData.kind ? null : pile.modelData.kind
            }
        }
    }

    // ---- bên trong một chồng ----
    Rectangle {
        id: stackPop
        visible: root.stacks && root.openStack !== null && pileItems.length > 0
        readonly property var pile: root.piles.find(p => p.kind === root.openStack) ?? null
        readonly property var pileItems: pile?.items ?? []
        readonly property int cols: Math.min(5, Math.max(1, pileItems.length))
        x: Math.min(root.pad + root.cellW + 10, root.width - width - 20)
        y: root.topY
        width: cols * root.cellW + 20
        height: Math.ceil(pileItems.length / cols) * root.cellH + 46
        radius: 20
        color: Qt.rgba(0.08, 0.08, 0.12, 0.92)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        Text {
            x: 16; y: 14
            text: stackPop.pile?.label ?? ""
            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
        }
        Grid {
            x: 10; y: 36
            columns: stackPop.cols
            Repeater {
                model: stackPop.pileItems
                Item {
                    required property var modelData
                    width: root.cellW; height: root.cellH
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4; radius: 12
                        color: sm.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10; width: 46; height: 46; sourceSize: Qt.size(92, 92)
                        source: parent.modelData.image ? "file://" + parent.modelData.image : Theme.icon(parent.modelData.icon)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text {
                        y: 62; width: parent.width - 8; x: 4
                        horizontalAlignment: Text.AlignHCenter
                        text: parent.modelData.app || parent.modelData.name
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 10
                        elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                    }
                    MouseArea {
                        id: sm
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { root.selected = parent.modelData.name; root.grabKeys(); }
                        onDoubleClicked: { DesktopFiles.open(parent.modelData.path); root.openStack = null; }
                    }
                }
            }
        }
    }

    // ================= menu chuột phải trên icon =================
    Rectangle {
        id: iconMenu
        visible: false
        z: 200
        width: 200
        height: imcol.implicitHeight + 12
        radius: 14
        color: Qt.rgba(0.11, 0.11, 0.15, 0.96)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        property var it: null
        function openAt(px, py, item) {
            it = item;
            x = Math.min(px, root.width - width - 8);
            y = Math.min(py, root.height - height - 8);
            visible = true;
        }
        function close() { visible = false; }
        Column {
            id: imcol
            x: 6; y: 6; width: parent.width - 12
            Row2 { icon: "folder"; label: iconMenu.it?.dir ? "Open folder" : "Open"; onClicked: { iconMenu.close(); DesktopFiles.open(iconMenu.it.path); } }
            Row2 { icon: "search"; label: "Quick Look  ·  Space"; visible: !(iconMenu.it?.dir ?? false); onClicked: { iconMenu.close(); QuickLook.show(iconMenu.it.path); } }
            Row2 { icon: "edit"; label: "Rename"; onClicked: { root.renaming = iconMenu.it.name; iconMenu.close(); } }
            Row2 { icon: "grid"; label: "New folder here"; onClicked: { iconMenu.close(); DesktopFiles.newFolder(null); } }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            Row2 { icon: "minus"; label: "Move to Trash"; danger: true; onClicked: { iconMenu.close(); DesktopFiles.trash([iconMenu.it.path]); root.selected = ""; } }
        }
    }
    MouseArea {
        anchors.fill: parent
        z: (iconMenu.visible || groupMenu.visible) ? 199 : -1
        enabled: iconMenu.visible || groupMenu.visible
        onPressed: { iconMenu.close(); groupMenu.close(); }
    }

    component Row2: Rectangle {
        id: mr
        property string icon: ""
        property string label: ""
        property bool danger: false
        signal clicked()
        width: parent ? parent.width : 180
        height: 34; radius: 9
        color: mra.containsMouse ? (mr.danger ? Qt.rgba(1, 0.37, 0.34, 0.25) : Theme.tint(0.3)) : "transparent"
        Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: mr.icon; size: 15; opacity: 0.9; color: mr.danger ? "#FF8A84" : "#FFFFFF" }
        Text { x: 36; anchors.verticalCenter: parent.verticalCenter; text: mr.label; color: mr.danger ? "#FF8A84" : "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        MouseArea { id: mra; anchors.fill: parent; hoverEnabled: true; onClicked: mr.clicked() }
    }
}
