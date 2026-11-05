import QtQuick
import "../theme"
import "../services"
import "../common"

// Tab "Lịch": lịch tháng bên trái, ghi chú của ngày đang chọn bên phải.
//   • gõ rồi Enter để thêm; "9:00 Họp nhóm" → ghi chú có giờ, đến giờ island nhắc
//   • bấm ô tròn: xong / chưa xong · rê vào: hiện ✕ để xoá
Item {
    id: root

    implicitHeight: 252
    // đang gõ dở thì island không tự thu lại
    readonly property bool editing: input.text !== ""

    property date viewMonth: new Date(Time.now.getFullYear(), Time.now.getMonth(), 1)
    property date selected: new Date(Time.now.getFullYear(), Time.now.getMonth(), Time.now.getDate())
    readonly property string selKey: Calendar.key(selected)

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]

    function shiftMonth(d) {
        viewMonth = new Date(viewMonth.getFullYear(), viewMonth.getMonth() + d, 1);
        gridSlide.dir = d;
        gridSlide.restart();
    }
    function goToday() {
        const n = Time.now;
        const target = new Date(n.getFullYear(), n.getMonth(), 1);
        const d = target > viewMonth ? 1 : target < viewMonth ? -1 : 0;
        viewMonth = target;
        selected = new Date(n.getFullYear(), n.getMonth(), n.getDate());
        if (d) { gridSlide.dir = d; gridSlide.restart(); }
    }
    function focusInput() { input.forceActiveFocus(); }
    function blurInput() { input.focus = false; }

    // 42 ô (6 tuần), tuần bắt đầu từ thứ Hai
    readonly property var cells: {
        const y = viewMonth.getFullYear(), m = viewMonth.getMonth();
        const first = new Date(y, m, 1);
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(y, m, 1 - lead + i));
        return out;
    }

    // ================= lịch tháng =================
    Item {
        id: cal
        width: 7 * 36
        height: parent.height

        // tiêu đề tháng
        Item {
            id: head
            width: parent.width
            height: 28
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.monthNames[root.viewMonth.getMonth()] + ", " + root.viewMonth.getFullYear()
                color: "#FFFFFF"
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                CalButton { label: "‹"; onClicked: root.shiftMonth(-1) }
                CalButton { label: "Today"; small: true; onClicked: root.goToday() }
                CalButton { label: "›"; onClicked: root.shiftMonth(1) }
            }
        }

        // thứ
        Row {
            id: weekdays
            y: head.height + 4
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Text {
                    required property string modelData
                    required property int index
                    width: 36
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index === 6 ? "#FF6A6A" : "#8E8E93"
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }

        // các ngày
        Item {
            y: weekdays.y + 18
            width: parent.width
            height: 6 * 32
            clip: true

            Grid {
                id: grid
                columns: 7
                transform: Translate { id: gridShift }

                Repeater {
                    model: root.cells
                    Item {
                        id: cell
                        required property var modelData
                        readonly property date d: modelData
                        readonly property bool inMonth: d.getMonth() === root.viewMonth.getMonth()
                        readonly property bool isToday: Calendar.key(d) === Calendar.key(Time.now)
                        readonly property bool isSel: Calendar.key(d) === root.selKey
                        readonly property int nNotes: Calendar.count(Calendar.key(d))
                        width: 36
                        height: 32

                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            width: 28
                            height: 28
                            radius: 14
                            color: cell.isToday ? "#FFFFFF" : cm.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                            border.width: cell.isSel && !cell.isToday ? 1.5 : 0
                            border.color: Theme.violet
                            scale: cm.pressed ? 0.88 : 1
                            Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.005 } }
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text {
                                anchors.centerIn: parent
                                text: cell.d.getDate()
                                color: cell.isToday ? "#000000"
                                    : !cell.inMonth ? "#48484A"
                                    : cell.d.getDay() === 0 ? "#FF8A8A" : "#F2F2F7"
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: cell.isToday || cell.isSel ? Font.Bold : Font.Medium
                                font.features: ({ "tnum": 1 })
                            }
                        }
                        // chấm: ngày có ghi chú
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            width: 4
                            height: 4
                            radius: 2
                            visible: cell.nNotes > 0
                            color: cell.inMonth ? Theme.violet : Theme.tint(0.4)
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selected = cell.d;
                                if (!cell.inMonth) root.shiftMonth(cell.d < root.viewMonth ? -1 : 1);
                                root.focusInput();
                            }
                        }
                    }
                }
            }
        }

        ParallelAnimation {
            id: gridSlide
            property int dir: 1
            NumberAnimation { target: gridShift; property: "x"; from: gridSlide.dir * 40; to: 0; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: grid; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        }
    }

    // vạch ngăn
    Rectangle {
        id: sep
        x: cal.width + 14
        y: 4
        width: 1
        height: parent.height - 8
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // ================= ghi chú =================
    Item {
        id: notesPane
        x: sep.x + 15
        width: parent.width - x
        height: parent.height

        Column {
            id: paneHead
            width: parent.width
            spacing: 1
            Text {
                text: Time.longDate(root.selected)
                color: "#FFFFFF"
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Text {
                readonly property int n: Calendar.count(root.selKey)
                readonly property int remaining: Calendar.pending(root.selKey)
                text: n === 0 ? "No notes" : remaining === 0 ? n + (n === 1 ? " note · done" : " notes · all done") : n + (n === 1 ? " note · " : " notes · ") + remaining + " left"
                color: "#8E8E93"
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        // danh sách
        Flickable {
            id: flick
            y: paneHead.height + 10
            width: parent.width
            height: inputBox.y - y - 8
            contentHeight: list.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: flick.width
                spacing: 4

                Repeater {
                    model: Calendar.list(root.selKey)

                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: Math.max(30, txt.implicitHeight + 12)
                        radius: 10
                        color: rm.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // hiện dần lần lượt
                        opacity: 0
                        Component.onCompleted: appear.start()
                        NumberAnimation on opacity { id: appear; running: false; to: 1; duration: 260; easing.type: Easing.OutCubic }

                        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                        // ô tròn xong / chưa
                        Rectangle {
                            id: check
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: row.modelData.done ? Theme.green : "transparent"
                            border.width: row.modelData.done ? 0 : 1.5
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                            Icon {
                                anchors.centerIn: parent
                                visible: row.modelData.done
                                name: "check"
                                size: 11
                                color: "#04201C"
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Calendar.toggle(root.selKey, row.modelData.id)
                            }
                        }

                        Text {
                            id: tm
                            visible: row.modelData.time !== ""
                            x: check.x + check.width + 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.time
                            color: Theme.violet
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.features: ({ "tnum": 1 })
                        }

                        Text {
                            id: txt
                            x: (tm.visible ? tm.x + tm.width : check.x + check.width) + 8
                            width: parent.width - x - 28
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.text
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: row.modelData.done ? "#636366" : "#F2F2F7"
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.strikeout: row.modelData.done
                        }

                        // xoá
                        Icon {
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            name: "close"
                            size: 12
                            color: dm.containsMouse ? "#FF6A6A" : "#8E8E93"
                            opacity: rm.containsMouse || dm.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            MouseArea {
                                id: dm
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Calendar.remove(root.selKey, row.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ô nhập
        Rectangle {
            id: inputBox
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: parent.width
            height: 34
            radius: 12
            color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.12 : 0.07)
            border.width: 1
            border.color: input.activeFocus ? Theme.tint(0.8) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Text {
                id: plus
                x: 11
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: Theme.violet
                font.pixelSize: 16
                font.bold: true
            }

            TextInput {
                id: input
                x: plus.x + plus.width + 8
                width: parent.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                selectionColor: Theme.violet
                font.family: Theme.font
                font.pixelSize: 12
                clip: true
                onAccepted: {
                    Calendar.add(root.selKey, text);
                    text = "";
                    flick.contentY = Math.max(0, flick.contentHeight - flick.height + 40);
                }
                Keys.onEscapePressed: { text = ""; focus = false; }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === "" && !input.activeFocus
                    text: "Add a note…  (e.g. 9:00 Team meeting)"
                    color: "#636366"
                    font: input.font
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === "" && input.activeFocus
                    text: "Type and press Enter"
                    color: "#636366"
                    font: input.font
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: input.forceActiveFocus()
                z: -1
            }
        }
    }

    component CalButton: Rectangle {
        id: cb
        property string label: ""
        property bool small: false
        signal clicked()
        width: small ? lb.implicitWidth + 14 : 24
        height: 24
        radius: 12
        color: m.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : small ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        Text {
            id: lb
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cb.small ? 0 : -1
            text: cb.label
            color: "#FFFFFF"
            font.family: Theme.font
            font.pixelSize: cb.small ? 11 : 16
            font.weight: cb.small ? Font.DemiBold : Font.Bold
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }
}
