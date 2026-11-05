import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Trung tâm thông báo: trượt ra từ góc phải trên khi bấm chuông trên thanh (hoặc Super+Shift+N).
// Thông báo mới nhất ở trên; vuốt sang phải / bấm × để bỏ; "Xoá hết" dọn sạch; công tắc Không làm phiền.
PanelWindow {
    id: win

    anchors { top: true; right: true; bottom: true }
    margins { top: 50; right: 12; bottom: 96 }
    implicitWidth: 384
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: true

    WlrLayershell.namespace: "islet-notifs"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Ui.notifOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    onOpenChanged: if (open) { Notifs.unread = 0; panel.forceActiveFocus(); }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Ui.notifOpen = false
    }

    // ListModel để có hiệu ứng thêm / bỏ từng thẻ
    ListModel { id: items }
    function sync() {
        const h = Notifs.history;
        const keep = new Set(h.map(x => x.uid));
        for (let i = items.count - 1; i >= 0; i--) if (!keep.has(items.get(i).uid)) items.remove(i);
        const have = new Set();
        for (let i = 0; i < items.count; i++) have.add(items.get(i).uid);
        for (let i = h.length - 1; i >= 0; i--) if (!have.has(h[i].uid)) items.insert(0, { uid: h[i].uid });
    }
    Connections { target: Notifs; function onHistoryChanged() { win.sync(); } }
    Component.onCompleted: sync()
    function info(uid) { return Notifs.history.find(h => h.uid === uid) ?? null; }

    // "vừa xong" · "5 phút" · "13:20" · "hôm qua"
    property date now: new Date()
    Timer { interval: 30000; running: win.open; repeat: true; triggeredOnStart: true; onTriggered: win.now = new Date() }
    function ago(t) {
        if (!t) return "";
        const s = (now - t) / 1000;
        if (s < 60) return "just now";
        if (s < 3600) return Math.floor(s / 60) + " min ago";
        const d = new Date(t);
        const pad = x => (x < 10 ? "0" : "") + x;
        if (d.toDateString() === now.toDateString()) return pad(d.getHours()) + ":" + pad(d.getMinutes());
        return d.getDate() + "/" + (d.getMonth() + 1);
    }

    Glass {
        id: panel
        width: parent.width
        height: Math.min(parent.height, head.height + (items.count > 0 ? list.contentHeight + 8 : empty.height + 26) + 34)
        radius: 28
        color: Qt.rgba(0.06, 0.06, 0.1, 0.6)
        clip: true

        transformOrigin: Item.TopRight
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.88
        x: win.open ? 0 : 24
        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 140; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.3; epsilon: 0.002 } }
        Behavior on x { SpringAnimation { spring: 4.2; damping: 0.32; epsilon: 0.1 } }
        Behavior on height { SpringAnimation { spring: 4; damping: 0.34; epsilon: 0.3 } }

        Keys.onEscapePressed: Ui.notifOpen = false

        // ---------- đầu ----------
        Item {
            id: head
            x: 18; y: 14
            width: parent.width - 36
            height: 40
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: "#FFFFFF"
                font.family: Theme.font
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Không làm phiền
                Rectangle {
                    height: 30
                    width: dndRow.implicitWidth + 22
                    radius: 15
                    color: Prefs.dnd ? Theme.tint(0.32) : dm.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: "moon"; size: 13; anchors.verticalCenter: parent.verticalCenter; color: Prefs.dnd ? Qt.lighter(Theme.accent, 1.35) : "#FFFFFF" }
                        Text { text: Prefs.dnd ? "Silenced" : "Do Not Disturb"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("dnd", !Prefs.dnd) }
                }
                Rectangle {
                    visible: items.count > 0
                    height: 30
                    width: clr.implicitWidth + 22
                    radius: 15
                    color: cm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    Text { id: clr; anchors.centerIn: parent; text: "Clear all"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearAll() }
                }
            }
        }

        // ---------- trống ----------
        Column {
            id: empty
            visible: items.count === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: head.y + head.height + 26
            height: 150
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64; radius: 32
                color: Qt.rgba(1, 1, 1, 0.06)
                Icon { anchors.centerIn: parent; name: Prefs.dnd ? "moon" : "bell"; size: 28; opacity: 0.7 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Prefs.dnd ? "Do Not Disturb is on — notifications are still kept here" : "Notifications from your apps will appear here"
                color: Qt.rgba(1, 1, 1, 0.42)
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        // ---------- danh sách ----------
        ListView {
            id: list
            x: 12
            y: head.y + head.height + 8
            width: parent.width - 24
            height: parent.height - y - 12
            spacing: 8
            clip: true
            model: items
            boundsBehavior: Flickable.StopAtBounds

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                    NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 340; easing.type: Easing.OutBack }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                    NumberAnimation { property: "x"; to: 380; duration: 260; easing.type: Easing.InCubic }
                }
            }
            displaced: Transition { SpringAnimation { property: "y"; spring: 4; damping: 0.35; epsilon: 0.2 } }

            delegate: Item {
                id: row
                required property int uid
                readonly property var n: win.info(uid)
                width: list.width
                height: card.height

                Rectangle {
                    id: card
                    width: parent.width
                    height: body.implicitHeight + 26
                    radius: 20
                    color: hov.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: row.n?.critical ? Qt.rgba(1, 0.42, 0.42, 0.5) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    opacity: 1 - Math.min(1, Math.abs(x) / 260)

                    HoverHandler { id: hov }
                    DragHandler {
                        id: drag
                        xAxis.minimum: 0
                        yAxis.enabled: false
                        onActiveChanged: if (!active) {
                            if (card.x > 120) Notifs.dismiss(row.uid);
                            else back.start();
                        }
                    }
                    NumberAnimation { id: back; target: card; property: "x"; to: 0; duration: 260; easing.type: Easing.OutBack }

                    // icon app
                    Rectangle {
                        id: ic
                        x: 12; y: 13
                        width: 38; height: 38; radius: 11
                        color: Qt.rgba(1, 1, 1, 0.08)
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: row.n?.icon ? 0 : 8
                            source: row.n?.icon ?? ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(76, 76)
                            visible: status === Image.Ready
                        }
                        Icon { anchors.centerIn: parent; name: "bell"; size: 18; visible: !(row.n?.icon) }
                    }

                    Column {
                        id: body
                        anchors.left: ic.right; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 14
                        y: 12
                        spacing: 2
                        Item {
                            width: parent.width
                            height: 16
                            Text {
                                text: row.n?.app ?? ""
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.family: Theme.font
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.right: parent.right
                                visible: !hov.hovered
                                text: win.ago(row.n?.time)
                                color: Qt.rgba(1, 1, 1, 0.38)
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            width: parent.width
                            text: row.n?.summary ?? ""
                            visible: text !== ""
                            elide: Text.ElideRight
                            color: "#FFFFFF"
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: row.n?.body ?? ""
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            color: Qt.rgba(1, 1, 1, 0.72)
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        Row {
                            visible: (row.n?.actions?.length ?? 0) > 0
                            topPadding: 6
                            spacing: 6
                            Repeater {
                                model: row.n?.actions ?? []
                                Rectangle {
                                    required property var modelData
                                    height: 26
                                    width: at.implicitWidth + 20
                                    radius: 13
                                    color: am.containsMouse ? Theme.tint(0.4) : Qt.rgba(1, 1, 1, 0.1)
                                    Text { id: at; anchors.centerIn: parent; text: parent.modelData.text; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: { Notifs.invoke(row.uid, parent.modelData.id); Notifs.dismiss(row.uid); } }
                                }
                            }
                        }
                    }

                    // nút ×
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.top: parent.top; anchors.topMargin: 8
                        width: 22; height: 22; radius: 11
                        visible: hov.hovered
                        color: xm.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12)
                        Icon { anchors.centerIn: parent; name: "close"; size: 11 }
                        MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.dismiss(row.uid) }
                    }
                }
            }
        }
    }
}
