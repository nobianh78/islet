import QtQuick
import "../theme"
import "../services"
import "../common"

// Tab Clipboard: lịch sử copy (chữ + ảnh). Bấm một mục → dán ngay vào cửa sổ đang dùng.
// Rê chuột: ghim (giữ lại khi Clear) · xoá. Mục ghim luôn nằm trên cùng. Ô tìm lọc theo chữ (ảnh ẩn khi đang tìm).
Item {
    id: root
    signal picked()                       // island thu lại để cửa sổ cũ nhận phím dán

    property string query: ""
    readonly property var all: Clipboard.items
    readonly property var items: {
        const q = query.trim().toLowerCase();
        return q ? all.filter(x => x.kind === "text" && x.text.toLowerCase().includes(q)) : all;
    }
    implicitHeight: head.height + 8 + (items.length ? Math.min(clipList.contentHeight, 236) : empty.implicitHeight)

    property date now: new Date()
    Timer { interval: 30000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
    function ago(t) {
        const s = (now - t) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    Item {
        id: head
        width: parent.width
        height: 24
        // ô tìm: bấm vào là gõ được (island nhận bàn phím khi cần)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 70; height: 24; radius: 12
            color: Qt.rgba(1, 1, 1, find.activeFocus ? 0.14 : 0.07)
            Icon { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 12; opacity: 0.6 }
            TextInput {
                id: find
                x: 28; width: parent.width - 52
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"; selectionColor: Theme.accent
                font.family: Theme.font; font.pixelSize: 12
                clip: true
                onTextChanged: root.query = text
                Keys.onEscapePressed: { text = ""; focus = false; }
            }
            Text {
                visible: find.text === "" && !find.activeFocus
                x: 28; anchors.verticalCenter: parent.verticalCenter
                text: root.all.length === 1 ? "Search 1 item" : "Search " + root.all.length + " items"
                color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
            }
            Text {
                visible: find.text !== ""
                anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                text: "\u00d7"; color: "#AEAEB2"; font.pixelSize: 15
                MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: { find.text = ""; find.focus = false; } }
            }
        }
        Text {
            visible: root.all.some(x => !x.pinned)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear"
            color: cm.containsMouse ? "#FFFFFF" : "#8E8E93"
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            MouseArea { id: cm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Clipboard.clear() }
        }
    }

    Text {
        id: empty
        visible: root.items.length === 0
        y: head.height + 8
        width: parent.width
        topPadding: 14
        bottomPadding: 20
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.query ? "Nothing matches “" + root.query + "”" : "Copy something — your history shows up here"
        color: "#8E8E93"
        font.family: Theme.font
        font.pixelSize: 12
    }

    ListView {
        id: clipList
        y: head.height + 8
        width: parent.width
        height: Math.min(contentHeight, 236)
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.items
        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 } }

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool isImage: modelData.kind === "image"
            width: clipList.width
            height: isImage ? 72 : Math.min(58, txt.implicitHeight + 20)
            radius: 14
            color: rm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            border.width: modelData.pinned ? 1 : 0
            border.color: Theme.tint(0.5)
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: rm.pressed ? 0.98 : 1
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; epsilon: 0.003 } }

            MouseArea {
                id: rm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { Clipboard.use(row.modelData, true); root.picked(); }
            }

            // chữ
            Text {
                id: txt
                visible: !row.isImage
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 14 - tools.width - 16
                text: row.isImage ? "" : row.modelData.text.replace(/\s+/g, " ").trim()
                maximumLineCount: 2
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                color: "#F2F2F7"
                font.family: /[{};=<>()]|^\s*(\$|#|sudo|git|npm|cd )/.test(text) ? Theme.mono : Theme.font
                font.pixelSize: 12
                textFormat: Text.PlainText
            }
            // ảnh
            Rounded {
                visible: row.isImage
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 96; height: 56
                radius: 9
                Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.06) }
                Image {
                    anchors.fill: parent
                    source: row.isImage ? "file://" + row.modelData.path : ""
                    sourceSize: Qt.size(192, 112)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {
                visible: row.isImage
                x: 118
                anchors.verticalCenter: parent.verticalCenter
                text: "Image"
                color: "#AEAEB2"
                font.family: Theme.font
                font.pixelSize: 12
            }

            // ghim / xoá / thời gian
            Row {
                id: tools
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    visible: !rm.containsMouse && !row.modelData.pinned
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.ago(row.modelData.time)
                    color: "#636366"
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Repeater {
                    model: [{ icon: "pin", act: "pin" }, { icon: "close", act: "del" }]
                    Rectangle {
                        required property var modelData
                        visible: rm.containsMouse || modelData.act === "pin" || bm.containsMouse
                        width: 24; height: 24; radius: 12
                        color: bm.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                        Icon {
                            anchors.centerIn: parent
                            name: parent.modelData.icon
                            size: 13
                            color: parent.modelData.act === "pin" && row.modelData.pinned ? Theme.accent : "#FFFFFF"
                            opacity: parent.modelData.act === "pin" && !row.modelData.pinned && !rm.containsMouse ? 0.3 : 1
                        }
                        MouseArea {
                            id: bm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.act === "pin" ? Clipboard.togglePin(row.modelData.id) : Clipboard.remove(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
