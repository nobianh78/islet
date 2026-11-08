import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Icon của file, thư mục và lối tắt trong ~/Desktop.
//   · bấm đúp để mở · kéo để dời chỗ (nhớ vị trí)
//   · kéo icon này thả lên icon kia = gom thành một thư mục mới; thả lên thư mục = bỏ vào trong
//   · chuột phải: mở · đổi tên · thư mục mới · bỏ vào thùng rác
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
    readonly property var items: DesktopFiles.items

    // ---- chồng theo loại (Stacks) ----
    readonly property var piles: {
        if (!stacks) return [];
        const by = {};
        for (const it of items) (by[it.kind] = by[it.kind] || []).push(it);
        return DesktopFiles.kindOrder.filter(k => by[k]).map(k => ({ kind: k, label: DesktopFiles.kindLabels[k], items: by[k] }));
    }

    function cellAt(i) {
        const rows = Math.max(1, Math.floor((root.height - topY - 110) / cellH));
        return Qt.point(pad + Math.floor(i / rows) * cellW, topY + (i % rows) * cellH);
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
    function clearSelection() { selected = ""; renaming = ""; }

    // thả icon lên icon khác: gom nhóm / bỏ vào thư mục
    function dropOn(src, dstName) {
        const dst = items.find(i => i.name === dstName);
        const from = items.find(i => i.name === src);
        if (!dst || !from || dst.name === from.name) return;
        const at = root.posOf(dst.name, root.autoIndexOf(dst.name));        // thư mục mới đứng đúng chỗ cái bị thả lên
        if (dst.dir) {
            DesktopFiles.run(["group", dst.name, from.path], null);          // thư mục có sẵn: chuyển vào trong
        } else {
            DesktopFiles.group("New Folder", [dst.path, from.path], (ok, out) => {
                if (ok && out) DesktopItems.setFilePos(out.split("/").pop(), at.x, at.y);
            });
            DesktopItems.clearFilePos(dst.name);
        }
        DesktopItems.clearFilePos(from.name);
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
            onPicked: { root.selected = modelData.name; root.renaming = ""; }
            onOpenRequested: DesktopFiles.open(modelData.path)
            onRenamed: n => { root.renaming = ""; if (n && n !== modelData.name) DesktopFiles.rename(modelData.path, n); }
            onMenuRequested: (gx, gy) => { root.selected = modelData.name; iconMenu.openAt(gx, gy, modelData); }
            onDragStarted: root.dragging = modelData.name
            onDragMoved: (gx, gy) => {
                let hit = "";
                for (const it of root.items) {
                    if (it.name === modelData.name) continue;
                    const p = root.posOf(it.name, root.autoIndexOf(it.name));
                    if (gx > p.x && gx < p.x + root.cellW && gy > p.y && gy < p.y + root.cellH) { hit = it.name; break; }
                }
                root.dropTarget = hit;
            }
            onDragEnded: (nx, ny) => {
                const t = root.dropTarget;
                root.dropTarget = ""; root.dragging = "";
                if (t) root.dropOn(modelData.name, t);
                else DesktopItems.setFilePos(modelData.name, nx, ny);
            }
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
                          : Quickshell.iconPath(pile.modelData.items[0]?.icon ?? "folder", true)
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
                        source: parent.modelData.image ? "file://" + parent.modelData.image : Quickshell.iconPath(parent.modelData.icon, true)
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
            Row2 { icon: "edit"; label: "Rename"; onClicked: { root.renaming = iconMenu.it.name; iconMenu.close(); } }
            Row2 { icon: "grid"; label: "New folder here"; onClicked: { iconMenu.close(); DesktopFiles.newFolder(null); } }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
            Row2 { icon: "minus"; label: "Move to Trash"; danger: true; onClicked: { iconMenu.close(); DesktopFiles.trash([iconMenu.it.path]); root.selected = ""; } }
        }
    }
    MouseArea {
        anchors.fill: parent
        z: iconMenu.visible ? 199 : -1
        enabled: iconMenu.visible
        onPressed: iconMenu.close()
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
