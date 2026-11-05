import QtQuick
import "../theme"
import "../services"
import "../common"

// Island mở rộng (chuyển từ _buildExpanded): tab Lịch · Bây giờ · Clipboard · Agents với viên trắng
// trượt theo tab đang chọn; trang đổi thì trượt ngang.
Item {
    id: root

    property string tab: "calendar"
    readonly property var order: ["calendar", "now", "timer", "clipboard", "agents"]
    readonly property var labels: ({ calendar: "Calendar", now: "Now", timer: "Timer", clipboard: "Clipboard", agents: "Agents" })
    readonly property real contentHeight: header.height + 10 + page.implicitHeight + 14 + 16
    readonly property color accent: Media.accent ?? "#30D158"
    property alias nowPage: nowPage
    property alias calendarPage: calPage
    property alias clipPage: clipPage
    property alias agentsPage: agentsPage

    signal tabSwitched(int dir)

    function switchTo(id) {
        if (id === tab) return;
        const dir = order.indexOf(id) > order.indexOf(tab) ? 1 : -1;
        tab = id;
        if (id === "calendar") calPage.focusInput();
        slide.dir = dir;
        slide.restart();
    }

    // ---------------- header ----------------
    Item {
        id: header
        x: 18
        y: 14
        width: parent.width - 36
        height: 30

        Item {
            id: tabs
            anchors.verticalCenter: parent.verticalCenter
            width: tabRow.width
            height: 26

            // viên trắng trượt tới tab đang chọn
            Rectangle {
                id: pill
                // itemAt() không tự cập nhật → đọc kèm count / width để binding chạy lại khi tab tạo xong.
                readonly property Item cur: {
                    tabRep.count; tabRow.width;
                    return tabRep.itemAt(root.order.indexOf(root.tab));
                }
                x: cur ? cur.x : 0
                width: cur ? cur.width : 0
                height: parent.height
                radius: height / 2
                color: "#FFFFFF"
                Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
            }

            Row {
                id: tabRow
                height: parent.height
                spacing: 4
                Repeater {
                    id: tabRep
                    model: root.order
                    Rectangle {
                        required property string modelData
                        readonly property bool active: root.tab === modelData
                        width: lbl.implicitWidth + 24
                        height: parent.height
                        radius: height / 2
                        color: !active && m.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text {
                            id: lbl
                            anchors.centerIn: parent
                            text: root.labels[parent.modelData]
                            color: parent.active ? "#000000" : m.containsMouse ? "#FFFFFF" : "#8E8E93"
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        MouseArea {
                            id: m
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchTo(parent.modelData)
                        }
                    }
                }
            }
        }

    }

    // ---------------- trang ----------------
    Item {
        id: page
        x: 18
        y: header.y + header.height + 10
        width: parent.width - 36
        implicitHeight: root.tab === "calendar" ? calPage.implicitHeight
            : root.tab === "now" ? nowPage.implicitHeight
            : root.tab === "timer" ? timerPage.implicitHeight
            : root.tab === "clipboard" ? clipPage.implicitHeight : agentsPage.implicitHeight
        height: implicitHeight

        CalendarPage { id: calPage; width: parent.width; visible: root.tab === "calendar" }
        NowPage { id: nowPage; width: parent.width; visible: root.tab === "now" }
        TimerPage { id: timerPage; width: parent.width; visible: root.tab === "timer" }
        ClipboardPage { id: clipPage; width: parent.width; visible: root.tab === "clipboard" }
        AgentsPage { id: agentsPage; width: parent.width; visible: root.tab === "agents" }

        transform: Translate { id: pageShift }
    }

    ParallelAnimation {
        id: slide
        property int dir: 1
        NumberAnimation { target: page; property: "opacity"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
        NumberAnimation { target: pageShift; property: "x"; from: slide.dir * 36; to: 0; duration: 340; easing.type: Easing.OutCubic }
    }
}
