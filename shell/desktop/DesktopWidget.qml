import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Một widget trên màn hình nền: thẻ kính mờ bọc quanh WidgetContent.
// Kéo chỗ nào cũng được để dời; rê chuột vào thì hiện nút gỡ ở góc.
Item {
    id: root
    property string uid: ""
    readonly property var st: DesktopItems.widget(uid)
    readonly property var meta: DesktopItems.kind(st?.kind ?? "")
    signal moved(real x, real y)

    readonly property real k: DesktopItems.widgetScale
    width: (meta?.w ?? 300) * k
    height: (meta?.h ?? 150) * k

    HoverHandler { id: hov }
    readonly property bool dragging: dragArea.drag.active

    MouseArea {
        id: dragArea
        anchors.fill: parent
        drag.target: root
        drag.threshold: 6
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property real px: 0
        property real py: 0
        onPressed: m => {
            px = root.x; py = root.y;
            if (m.button === Qt.RightButton) { m.accepted = false; return; }       // menu màn hình nền
        }
        onReleased: if (Math.abs(root.x - px) > 1 || Math.abs(root.y - py) > 1) root.moved(root.x, root.y)
        onClicked: m => {
            if (m.button !== Qt.LeftButton) return;
            const k = root.st?.kind ?? "";
            if (k === "calendar") Ui.openIsland("calendar");
            else if (k === "timer") Ui.openIsland("timer");
            else if (k === "media") Ui.openIsland("now");
            else if (k === "system" || k === "disk" || k === "net") Ui.toggleTask();
            else if (k === "clock" || k === "analog" || k === "world") Ui.openSettings("datetime");
            else if (k === "weather") Ui.openSettings("island");
            else if (k === "battery") Ui.openSettings("power");
            else if (k === "sysinfo") Ui.openSettings("about");
            else if (k === "photo") Quickshell.execDetached(["xdg-open", root.st?.conf?.dir || (Quickshell.env("HOME") + "/Pictures")]);
        }
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent?.width ?? 2000) - root.width
        drag.maximumY: (root.parent?.height ?? 2000) - root.height
    }

    // vẽ ở cỡ gốc (meta.w × meta.h) rồi thu theo k
    Item {
        id: holder
        width: meta?.w ?? 300
        height: meta?.h ?? 150
        scale: root.k * (root.dragging ? 1.05 : 1)
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

        Glass {
            anchors.fill: parent
            radius: 30
            color: Theme.light ? Qt.rgba(1, 1, 1, 0.36) : Qt.rgba(0.1, 0.1, 0.16, 0.34)
        }
        WidgetContent {
            anchors.fill: parent
            anchors.margins: 20
            kind: root.st?.kind ?? ""
            conf: root.st?.conf ?? ({})
        }
    }

    // nút gỡ (rê chuột vào mới hiện)
    Rectangle {
        x: -7; y: -7; width: 24; height: 24; radius: 12
        color: rmA.containsMouse ? "#FF5F57" : Qt.rgba(0.2, 0.2, 0.25, 0.95)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
        opacity: hov.hovered && !root.dragging ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Icon { anchors.centerIn: parent; name: "minus"; size: 13 }
        MouseArea {
            id: rmA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: DesktopItems.removeWidget(root.uid)
        }
    }
}
