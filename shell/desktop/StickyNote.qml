import QtQuick
import "../theme"
import "../services"
import "../common"

// Ghi chú dán trên màn hình nền. Kéo thanh trên để dời, kéo góc dưới phải để đổi cỡ,
// chấm màu để đổi màu, × để bỏ (bấm hai lần nếu ghi chú còn chữ). Tự lưu khi gõ.
Item {
    id: root
    property string noteId: ""
    readonly property var note: DesktopItems.note(noteId) ?? ({})
    property size area: Qt.size(1920, 1080)
    readonly property string nid: noteId

    x: Math.max(0, Math.min(note.x ?? 100, area.width - width))
    y: Math.max(0, Math.min(note.y ?? 100, area.height - 40))
    width: Math.max(170, note.w ?? 230)
    height: Math.max(130, note.h ?? 210)
    z: 10 + DesktopItems.order(nid)          // ghi chú vừa chạm lên trên cùng

    property bool armed: false
    HoverHandler { id: hov }

    Connections {
        target: DesktopItems
        function onFocusNote(id) { if (id === root.nid) edit.forceActiveFocus(); }
    }

    // bóng
    Rectangle {
        anchors.fill: paper; anchors.topMargin: 6; anchors.leftMargin: 3; anchors.rightMargin: -3; anchors.bottomMargin: -8
        radius: paper.radius; color: Qt.rgba(0, 0, 0, 0.28)
    }
    Rectangle {
        id: paper
        anchors.fill: parent
        radius: 14
        color: root.note.color ?? "#FFD966"
        Behavior on color { ColorAnimation { duration: 200 } }
        // dải đậm hơn ở trên (chỗ cầm)
        Rectangle {
            id: bar
            width: parent.width; height: 30; radius: 14
            color: Qt.darker(paper.color, 1.08)
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: parent.color }
        }
    }

    // kéo để dời
    MouseArea {
        anchors.left: parent.left; anchors.right: parent.right
        height: 30
        drag.target: root
        drag.threshold: 3
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: DesktopItems.raiseNote(root.nid)
        onReleased: DesktopItems.setNote(root.nid, { x: Math.round(root.x), y: Math.round(root.y) })
    }
    // màu · bỏ
    Row {
        x: 10; anchors.verticalCenter: bar.verticalCenter
        spacing: 6
        opacity: hov.hovered || edit.activeFocus ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Repeater {
            model: DesktopItems.noteColors
            Rectangle {
                required property string modelData
                width: 12; height: 12; radius: 6
                color: modelData
                border.width: Qt.colorEqual(modelData, root.note.color ?? "") ? 2 : 1
                border.color: Qt.rgba(0, 0, 0, Qt.colorEqual(modelData, root.note.color ?? "") ? 0.55 : 0.2)
                MouseArea { anchors.fill: parent; anchors.margins: -3; onClicked: DesktopItems.setNote(root.nid, { color: modelData }) }
            }
        }
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: bar.verticalCenter
        width: root.armed ? delT.implicitWidth + 16 : 20; height: 20; radius: 10
        color: root.armed ? "#E5484D" : xm.containsMouse ? Qt.rgba(0, 0, 0, 0.16) : "transparent"
        opacity: hov.hovered || root.armed ? 1 : 0
        Behavior on width { NumberAnimation { duration: 140 } }
        Text { id: delT; anchors.centerIn: parent; text: root.armed ? "Delete" : "×"; color: root.armed ? "#FFFFFF" : Qt.rgba(0, 0, 0, 0.6); font.family: Theme.font; font.pixelSize: root.armed ? 11 : 16; font.weight: Font.Bold }
        MouseArea {
            id: xm; anchors.fill: parent; hoverEnabled: true
            onClicked: {
                if (edit.text.trim() === "" || root.armed) { DesktopItems.removeNote(root.nid); return; }
                root.armed = true; disarm.restart();
            }
        }
        Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }
    }

    // chữ
    Flickable {
        id: fl
        anchors.fill: parent
        anchors.topMargin: 34; anchors.leftMargin: 14; anchors.rightMargin: 12; anchors.bottomMargin: 14
        contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: edit
            width: fl.width
            Component.onCompleted: text = root.note.text ?? ""
            wrapMode: TextEdit.Wrap
            color: "#2B2412"
            selectionColor: Qt.rgba(0, 0, 0, 0.2)
            selectedTextColor: "#1C1710"
            font.family: Theme.font
            font.pixelSize: 14
            selectByMouse: true
            onTextChanged: if (text !== (root.note.text ?? "")) saveT.restart()
            onActiveFocusChanged: if (activeFocus) DesktopItems.raiseNote(root.nid)
            onCursorRectangleChanged: {
                if (cursorRectangle.y < fl.contentY) fl.contentY = cursorRectangle.y;
                else if (cursorRectangle.y + cursorRectangle.height > fl.contentY + fl.height) fl.contentY = cursorRectangle.y + cursorRectangle.height - fl.height;
            }
            Keys.onEscapePressed: root.forceActiveFocus()
        }
        Text {
            visible: edit.text === "" && !edit.activeFocus
            text: "Write something…"
            color: Qt.rgba(0, 0, 0, 0.35); font.family: Theme.font; font.pixelSize: 14
        }
    }
    Timer { id: saveT; interval: 500; onTriggered: DesktopItems.setNote(root.nid, { text: edit.text }) }

    // đổi cỡ (góc dưới phải)
    MouseArea {
        width: 18; height: 18
        anchors.right: parent.right; anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        property point start
        property size from
        onPressed: m => { start = mapToItem(root.parent, m.x, m.y); from = Qt.size(root.width, root.height); }
        onPositionChanged: m => {
            const p = mapToItem(root.parent, m.x, m.y);
            root.width = Math.max(170, from.width + p.x - start.x);
            root.height = Math.max(130, from.height + p.y - start.y);
        }
        onReleased: DesktopItems.setNote(root.nid, { w: Math.round(root.width), h: Math.round(root.height) })
        Canvas {
            anchors.fill: parent; opacity: hov.hovered ? 0.45 : 0
            onPaint: {
                const c = getContext("2d"); c.strokeStyle = "#000"; c.lineWidth = 1.2;
                for (const o of [6, 11]) { c.beginPath(); c.moveTo(width - 3, height - o); c.lineTo(width - o, height - 3); c.stroke(); }
            }
        }
    }
}
