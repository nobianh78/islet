import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Menu nguồn: bấm logo mèo trên thanh trên.
//   Ngủ chạy ngay; Khởi động lại / Tắt máy / Đăng xuất phải bấm 2 lần (lần đầu ô đổi màu,
//   "Bấm lần nữa để …", 3 giây không bấm thì thôi). Bấm ra ngoài hoặc Esc để đóng.
PanelWindow {
    id: win

    anchors { top: true; left: true }
    margins { top: 48; left: 8 }
    implicitWidth: 280
    implicitHeight: 470
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: true

    WlrLayershell.namespace: "islet-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property bool open: Ui.powerOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    property string armed: ""      // hành động đang chờ bấm lần 2
    onOpenChanged: { armed = ""; if (open) { uptime.reload(); panel.forceActiveFocus(); } }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Ui.powerOpen = false
    }

    readonly property var actions: [
        { id: "settings", icon: "settings", label: "Settings",       confirm: "",                         cmd: [] },
        { id: "task",    icon: "activity", label: "Task Manager", confirm: "",                         cmd: [] },
        { id: "lock",    icon: "lock",    label: "Lock Screen",  confirm: "",                          cmd: [] },
        { id: "sleep",   icon: "sleep",   label: "Sleep",           confirm: "",                          cmd: ["systemctl", "suspend"] },
        { id: "restart", icon: "restart", label: "Restart", confirm: "Click again to restart", cmd: ["systemctl", "reboot"] },
        { id: "power",   icon: "power",   label: "Shut Down",       confirm: "Click again to shut down",     cmd: ["systemctl", "poweroff"] },
        { id: "logout",  icon: "logout",  label: "Log Out",     confirm: "Click again to log out",   cmd: [] }
    ]

    function run(a) {
        if (a.confirm && armed !== a.id) {
            armed = a.id;
            disarm.restart();
            return;
        }
        armed = "";
        Ui.powerOpen = false;
        if (a.id === "task") Ui.toggleTask();
        else if (a.id === "settings") Ui.openSettings("");
        else if (a.id === "lock") Ui.lock();
        else if (a.id === "sleep") { Ui.lock(); sleepLater.restart(); }
        else if (a.id === "logout") Hyprland.dispatch("hl.dsp.exit()");
        else Quickshell.execDetached(a.cmd);
    }
    // khoá trước rồi mới ngủ, để lúc thức dậy là màn hình khoá
    Timer { id: sleepLater; interval: 900; onTriggered: Quickshell.execDetached(["systemctl", "suspend"]) }
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

    // thời gian đã bật máy
    FileView { id: uptime; path: "/proc/uptime"; blockLoading: true }
    readonly property string uptimeText: {
        const sec = parseFloat((uptime.text() || "0").split(" ")[0]) || 0;
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        if (d > 0) return "up " + d + "d " + h + "h";
        if (h > 0) return "up " + h + "h " + m + "m";
        return "up " + Math.max(1, m) + "m";
    }

    Glass {
        id: panel
        width: parent.width
        height: col.implicitHeight + 20
        radius: 24
        color: Theme.surface(0.62)

        transformOrigin: Item.TopLeft
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.82
        Behavior on opacity { NumberAnimation { duration: win.open ? 170 : 130; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4.4; damping: 0.3; epsilon: 0.002 } }

        Keys.onEscapePressed: Ui.powerOpen = false

        Column {
            id: col
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 4

            // đầu: logo + tên máy + thời gian đã bật
            Row {
                leftPadding: 6
                bottomPadding: 6
                topPadding: 4
                spacing: 12
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    sourceSize: Qt.size(80, 80)
                    source: Theme.appIcon("islet")
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "Islet"
                        color: Theme.label
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                    Text {
                        text: (Quickshell.env("USER") || "islet") + " · " + win.uptimeText
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.fg(0.08) }

            Repeater {
                model: win.actions

                Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool armed: win.armed === modelData.id
                    readonly property color danger: modelData.id === "power" ? "#FF5F57" : modelData.id === "restart" ? "#FFA43A" : Theme.violet

                    width: col.width
                    height: 44
                    radius: 14
                    color: armed ? Qt.rgba(danger.r, danger.g, danger.b, 0.9)
                        : m.containsMouse ? Theme.fg(0.10) : "transparent"
                    Behavior on color { ColorAnimation { duration: 160 } }
                    scale: m.pressed ? 0.96 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }

                    // hiện lần lượt khi mở
                    opacity: win.open ? 1 : 0
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: win.open ? 40 + item.index * 35 : 0 }
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                    }

                    // vạch đếm ngược 3 giây khi chờ xác nhận
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.bottomMargin: 5
                        height: 2
                        radius: 1
                        color: Theme.fg(0.7)
                        width: 0
                        visible: item.armed
                        NumberAnimation on width {
                            running: item.armed
                            from: item.width - 20
                            to: 0
                            duration: 3000
                        }
                    }

                    // icon trong ô tròn
                    Rectangle {
                        id: badge
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 15
                        color: item.armed ? Theme.fg(0.22) : Theme.fg(0.08)
                        TIcon {
                            anchors.centerIn: parent
                            name: item.modelData.icon
                            size: 17
                            rotation: item.armed && item.modelData.id === "restart" ? 360 : 0
                            Behavior on rotation { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                        }
                    }

                    Text {
                        anchors.left: badge.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.armed ? item.modelData.confirm : item.modelData.label
                        color: Theme.label
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: item.armed ? Font.Bold : Font.Medium
                    }

                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.run(item.modelData)
                    }
                }
            }
        }
    }
}
