import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import "../theme"
import "../services"
import "../common"

// Thanh trên cùng: logo · workspace · app đang mở  ……  mạng · âm lượng · Bluetooth · pin · [nút điều khiển].
// Island nằm đè ở giữa, như tai thỏ.
PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    implicitHeight: 44
    exclusiveZone: 44
    color: "transparent"

    WlrLayershell.namespace: "islet-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property var active: ToplevelManager.activeToplevel
    readonly property var appNames: ({
        "kitty": "Terminal",
        "firefox": "Firefox",
        "org.gnome.Nautilus": "Files",
        "mpv": "Music"
    })
    readonly property string appName: {
        if (!active || !active.activated) return "Islet";
        const id = active.appId ?? "";
        if (id === "org.quickshell") return active.title || "Islet";      // cửa sổ của chính Islet (Cài đặt)
        return appNames[id] ?? (id.split(".").pop() || "Islet");
    }

    // Lớp tối rất nhẹ phía trên để chữ trắng luôn đọc được.
    // trượt vào sau khi mở khoá (nối tiếp hiệu ứng của màn hình khoá)
    Item {
        id: reveal
        property real v: Ui.locked ? 0 : 1
        Behavior on v {
            SequentialAnimation {
                PauseAnimation { duration: Ui.locked ? 0 : 80 }
                NumberAnimation { duration: Ui.locked ? 0 : 750; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }
        }
    }

    Rectangle {
        transform: Translate { y: -48 * (1 - reveal.v) }
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    // ---------------- Trái ----------------
    Row {
        transform: Translate { y: -48 * (1 - reveal.v) }
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Item {
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: logo
                anchors.centerIn: parent
                width: 22
                height: 22
                sourceSize: Qt.size(44, 44)
                source: Qt.resolvedUrl("../assets/icons/islet.svg")
                scale: logoMouse.pressed ? 0.85 : logoMouse.containsMouse ? 1.12 : 1
                rotation: logoMouse.containsMouse ? -8 : 0
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.3 } }
                Behavior on rotation { SpringAnimation { spring: 4; damping: 0.25 } }
            }
            MouseArea {
                id: logoMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.togglePower()
            }
        }

        Workspaces { anchors.verticalCenter: parent.verticalCenter }

        WindowControls { anchors.verticalCenter: parent.verticalCenter }

        Text {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            text: bar.appName
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold

            // Đổi app thì chữ trượt lên nhẹ.
            onTextChanged: slide.restart()
            SequentialAnimation {
                id: slide
                ParallelAnimation {
                    NumberAnimation { target: title; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { target: titleShift; property: "y"; from: 6; to: 0; duration: 380; easing.type: Easing.OutBack }
                }
            }
            transform: Translate { id: titleShift }

            // Chuột giữa: đóng cửa sổ. Lăn chuột: chuyển qua lại các cửa sổ.
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                acceptedButtons: Qt.MiddleButton
                hoverEnabled: true
                onContainsMouseChanged: Ui.frameHint = containsMouse
                onClicked: Windows.close()
                property real acc: 0
                onWheel: w => {
                    acc += w.angleDelta.y;
                    if (Math.abs(acc) < 120) return;
                    Windows.cycle(acc < 0);
                    acc = 0;
                }
            }
        }
    }

    // ---------------- Phải: trạng thái hệ thống + nút trung tâm điều khiển ----------------
    Row {
        transform: Translate { y: -48 * (1 - reveal.v) }
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // cụm trạng thái (bấm cũng mở trung tâm điều khiển)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: statusRow.implicitWidth + 22
            radius: 16
            color: statusMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
            Behavior on color { ColorAnimation { duration: 160 } }

            MouseArea {
                id: statusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleControlCenter()
            }

            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 13

                // bộ gõ: VI / EN — bấm để chuyển (Ctrl+Space cũng được)
                Rectangle {
                    visible: Prefs.imeEnabled && Ime.running
                    anchors.verticalCenter: parent.verticalCenter
                    width: imeText.implicitWidth + 12
                    height: 18
                    radius: 6
                    color: Ime.vietnamese ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        id: imeText
                        anchors.centerIn: parent
                        text: Ime.vietnamese ? "VI" : "EN"
                        color: "#FFFFFF"
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Ime.toggle() }
                }

                // mạng: Wi-Fi theo độ mạnh sóng / dây / mất mạng
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 17
                    name: Net.kind === "wifi" ? (Net.strength > 0.66 ? "wifi" : Net.strength > 0.33 ? "wifi-2" : "wifi-1")
                        : Net.kind === "ethernet" ? "ethernet" : "wifi-off"
                    opacity: Net.connected ? 1 : 0.55
                }

                // âm lượng: lăn chuột để chỉnh, bấm để tắt / bật tiếng
                Icon {
                    id: vol
                    anchors.verticalCenter: parent.verticalCenter
                    size: 17
                    name: Audio.muted || Audio.volume <= 0.001 ? "volume-mute" : Audio.volume < 0.5 ? "volume-low" : "volume"
                    opacity: Audio.muted ? 0.55 : 1
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }

                // Bluetooth: chỉ hiện khi máy có
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Bluetooth.defaultAdapter !== null
                    size: 16
                    name: "bluetooth"
                    opacity: Bluetooth.defaultAdapter?.enabled ? 1 : 0.45
                }

                // pin + %: chỉ hiện trên laptop
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Power.present
                    spacing: 5
                    BatteryIcon { anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Power.percent) + "%"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }

        // nút chuông: mở trung tâm thông báo; chấm màu nhấn khi có thông báo chưa xem
        Rectangle {
            id: bellBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: Ui.notifOpen ? Qt.rgba(1, 1, 1, 0.92)
                : bellMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 160 } }
            scale: bellMouse.pressed ? 0.88 : 1
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.005 } }

            Icon {
                id: bellIcon
                anchors.centerIn: parent
                name: Prefs.dnd ? "moon" : "bell"
                size: 16
                color: Ui.notifOpen ? "#07070F" : "#FFFFFF"
                // lắc nhẹ khi có thông báo mới
                SequentialAnimation on rotation {
                    id: ring
                    running: false
                    NumberAnimation { to: 18; duration: 70 }
                    NumberAnimation { to: -15; duration: 110 }
                    NumberAnimation { to: 10; duration: 110 }
                    NumberAnimation { to: -6; duration: 100 }
                    NumberAnimation { to: 0; duration: 120 }
                }
                Connections { target: Notifs; function onArrived() { if (!Prefs.dnd) ring.restart(); } }
            }
            Rectangle {
                visible: Notifs.unread > 0 && !Ui.notifOpen
                anchors.right: parent.right; anchors.top: parent.top
                anchors.rightMargin: 5; anchors.topMargin: 5
                width: 8; height: 8; radius: 4
                color: Theme.accent
                border.width: 1.5
                border.color: "#0A0A14"
                scale: visible ? 1 : 0
                Behavior on scale { SpringAnimation { spring: 6; damping: 0.3 } }
            }
            MouseArea {
                id: bellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleNotifs()
            }
        }

        // nút mở trung tâm điều khiển
        Rectangle {
            id: ccBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: Ui.controlCenterOpen ? Qt.rgba(1, 1, 1, 0.92)
                : ccMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 160 } }
            scale: ccMouse.pressed ? 0.88 : 1
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.005 } }

            Icon {
                anchors.centerIn: parent
                name: "sliders"
                size: 16
                color: Ui.controlCenterOpen ? "#07070F" : "#FFFFFF"
                rotation: Ui.controlCenterOpen ? 90 : 0
                Behavior on rotation { SpringAnimation { spring: 4; damping: 0.3; epsilon: 0.1 } }
            }
            MouseArea {
                id: ccMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleControlCenter()
            }
        }
    }
}
