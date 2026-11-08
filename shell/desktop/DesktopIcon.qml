import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Một icon trên màn hình nền (file, thư mục hoặc lối tắt).
Item {
    id: root
    property var item: ({})
    property point home: Qt.point(0, 0)
    property size area: Qt.size(1920, 1080)
    property bool selected: false
    property bool renaming: false
    property bool dropHover: false

    signal picked()
    signal openRequested()
    signal renamed(string name)
    signal menuRequested(real gx, real gy)
    signal dragStarted()
    signal dragMoved(real gx, real gy)
    signal dragEnded(real x, real y)

    width: 96
    height: 104
    x: home.x
    y: home.y
    z: ma.drag.active ? 50 : 1
    Behavior on x { enabled: !ma.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !ma.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    onRenamingChanged: if (renaming) { nameIn.text = item.name; nameIn.forceActiveFocus(); nameIn.selectAll(); }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 14
        color: root.dropHover ? Theme.tint(0.45) : root.selected ? Theme.tint(0.3) : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
        border.width: root.dropHover ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Image {
        id: img
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: 48; height: 48
        sourceSize: Qt.size(96, 96)
        source: root.item.image ? "file://" + root.item.image : Quickshell.iconPath(root.item.icon ?? "text-x-generic", true)
        fillMode: root.item.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        asynchronous: true
        scale: ma.drag.active ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 140 } }
        // ảnh: bo góc nhẹ cho giống tấm hình
        layer.enabled: root.item.image !== null && root.item.image !== undefined && root.item.image !== ""
        layer.smooth: true
    }
    // số mục trong thư mục
    Rectangle {
        visible: root.item.dir && (root.item.count ?? 0) > 0
        anchors.right: img.right; anchors.rightMargin: -4
        anchors.top: img.top; anchors.topMargin: -4
        width: Math.max(18, cnt.implicitWidth + 8); height: 18; radius: 9
        color: Theme.accent
        Text { id: cnt; anchors.centerIn: parent; text: root.item.count ?? 0; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Bold }
    }

    Text {
        id: label
        visible: !root.renaming
        y: 62
        x: 4
        width: parent.width - 8
        horizontalAlignment: Text.AlignHCenter
        text: root.item.app || root.item.name || ""
        color: "#FFFFFF"
        font.family: Theme.font; font.pixelSize: 11
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.6)
    }
    // đổi tên tại chỗ
    Rectangle {
        visible: root.renaming
        y: 60; x: 2
        width: parent.width - 4; height: 24
        radius: 7
        color: Qt.rgba(0.1, 0.1, 0.14, 0.96)
        border.width: 1; border.color: Theme.accent
        TextInput {
            id: nameIn
            anchors.fill: parent
            anchors.margins: 5
            color: "#FFFFFF"
            selectionColor: Theme.accent
            font.family: Theme.font; font.pixelSize: 11
            clip: true
            onAccepted: root.renamed(text.trim())
            Keys.onEscapePressed: root.renamed("")
            onActiveFocusChanged: if (!activeFocus && root.renaming) root.renamed(text.trim())
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: root
        drag.threshold: 6
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: root.area.width - root.width
        drag.maximumY: root.area.height - root.height
        cursorShape: Qt.PointingHandCursor
        property bool moved: false
        onPressed: m => {
            moved = false;
            if (m.button === Qt.RightButton) { root.menuRequested(root.x + m.x, root.y + m.y); return; }
            root.picked();
        }
        onPositionChanged: if (drag.active) { if (!moved) { moved = true; root.dragStarted(); } root.dragMoved(root.x + width / 2, root.y + height / 2); }
        onReleased: m => { if (moved) root.dragEnded(root.x, root.y); }
        onDoubleClicked: m => { if (m.button === Qt.LeftButton) root.openRequested(); }
    }
}
