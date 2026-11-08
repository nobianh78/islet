import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Khung gom file trên màn hình nền — như gom app trên điện thoại: một ô vuông bo tròn, bên trong là
// mấy icon nhỏ xem trước. File vẫn nằm nguyên trong ~/Desktop, khung chỉ là cách sắp xếp.
Item {
    id: root
    property var group: ({})
    property var members: []          // [{ name, icon, image, … }] của các file trong khung
    property size area: Qt.size(1920, 1080)
    property bool open: false
    property bool dropHover: false

    signal picked()
    signal openRequested()
    signal menuRequested(real gx, real gy)
    signal dragStarted()
    signal dragMoved(real gx, real gy)
    signal dragEnded(real x, real y)

    width: 96
    height: 104
    x: group.x ?? 0
    y: group.y ?? 0
    z: ma.drag.active ? 50 : 2
    Behavior on x { enabled: !ma.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !ma.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 14
        color: root.dropHover ? Theme.tint(0.45) : root.open ? Theme.tint(0.3) : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
        border.width: root.dropHover ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ô chứa, bên trong là lưới 2×2 icon nhỏ
    Rectangle {
        id: box
        width: 56; height: 56; radius: 16
        x: (parent.width - 56) / 2; y: 8
        color: Qt.rgba(1, 1, 1, 0.13)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
        scale: ma.drag.active ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 140 } }
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 4
            Repeater {
                model: root.members.slice(0, 4)
                Item {
                    required property var modelData
                    width: 20; height: 20
                    Image {
                        anchors.fill: parent
                        source: modelData.image ? "file://" + modelData.image : Quickshell.iconPath(modelData.icon ?? "text-x-generic", true)
                        fillMode: modelData.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        sourceSize: Qt.size(40, 40)
                        asynchronous: true
                        smooth: true
                    }
                }
            }
        }
        // còn bao nhiêu nữa
        Rectangle {
            visible: root.members.length > 4
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: -3
            width: Math.max(18, more.implicitWidth + 8); height: 18; radius: 9
            color: Theme.accent
            Text { id: more; anchors.centerIn: parent; text: "+" + (root.members.length - 4); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.Bold }
        }
    }

    Text {
        y: 68; x: 4
        width: parent.width - 8
        horizontalAlignment: Text.AlignHCenter
        text: (root.group.name || "Group") + " (" + root.members.length + ")"
        color: "#FFFFFF"
        font.family: Theme.font; font.pixelSize: 11
        elide: Text.ElideRight
        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.6)
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
        onReleased: if (moved) root.dragEnded(root.x, root.y)
        onClicked: m => { if (m.button === Qt.LeftButton && !moved) root.openRequested(); }
    }
}
