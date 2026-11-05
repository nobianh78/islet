import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Quản lý tác vụ: Hiệu năng · Ứng dụng · Tiến trình.
// Mở: Ctrl+Shift+Esc, menu logo mèo, hoặc `qs ipc call taskmgr toggle`. Đóng: Esc / ✕ / bấm ra ngoài.
PanelWindow {
    id: win

    implicitWidth: 840
    implicitHeight: 560
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-taskmgr"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool open: Ui.taskOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    onOpenChanged: {
        SysMon.active = open;
        if (open) panel.forceActiveFocus();
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Ui.taskOpen = false
    }

    property string tab: "perf"
    readonly property var tabs: [["perf", "Performance"], ["apps", "Apps"], ["procs", "Processes"]]

    Glass {
        id: panel
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0.05, 0.05, 0.09, 0.82)

        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 140; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.002 } }

        Keys.onEscapePressed: Ui.taskOpen = false

        // ================= đầu =================
        Item {
            id: head
            x: 22
            y: 18
            width: parent.width - 44
            height: 36

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Rectangle {
                    width: 34
                    height: 34
                    radius: 11
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#4BE3E8" }
                        GradientStop { position: 1; color: Theme.violet }
                    }
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.strokeStyle = "#FFFFFF";
                            c.lineWidth = 2.6;
                            c.lineCap = "round";
                            c.lineJoin = "round";
                            c.beginPath();
                            c.moveTo(7, 19); c.lineTo(12, 19); c.lineTo(15, 11); c.lineTo(19, 24); c.lineTo(22, 16); c.lineTo(27, 16);
                            c.stroke();
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "Task Manager"
                        color: "#FFFFFF"
                        font.family: Theme.font
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "Islet · up " + SysMon.duration(SysMon.uptime) + " · " + SysMon.procs.length + " processes"
                        color: "#8E8E93"
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }

            // tab
            Item {
                anchors.centerIn: parent
                width: tabRow.width
                height: 30
                Rectangle {
                    readonly property Item cur: { tabRep.count; tabRow.width; return tabRep.itemAt(win.tabs.findIndex(t => t[0] === win.tab)); }
                    x: cur ? cur.x : 0
                    width: cur ? cur.width : 0
                    height: parent.height
                    radius: height / 2
                    color: "#FFFFFF"
                    Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                }
                Row {
                    id: tabRow
                    height: parent.height
                    spacing: 4
                    Repeater {
                        id: tabRep
                        model: win.tabs
                        Item {
                            required property var modelData
                            readonly property bool on: win.tab === modelData[0]
                            width: tl.implicitWidth + 28
                            height: parent.height
                            Text {
                                id: tl
                                anchors.centerIn: parent
                                text: parent.modelData[1]
                                color: parent.on ? "#000000" : tm.containsMouse ? "#FFFFFF" : "#8E8E93"
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            MouseArea {
                                id: tm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.tab = parent.modelData[0]
                            }
                        }
                    }
                }
            }

            // đóng
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 15
                color: xm.containsMouse ? "#FF5F57" : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 140 } }
                Icon { anchors.centerIn: parent; name: "close"; size: 14 }
                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.taskOpen = false }
            }
        }

        // ================= nội dung =================
        Item {
            id: body
            x: 22
            y: head.y + head.height + 18
            width: parent.width - 44
            height: parent.height - y - 22

            PerfPage { anchors.fill: parent; visible: win.tab === "perf" }
            AppsPage { anchors.fill: parent; visible: win.tab === "apps" }
            ProcsPage { anchors.fill: parent; visible: win.tab === "procs" }
        }
    }
}
