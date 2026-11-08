import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../theme"
import "../services"
import "../common"
import "../island"

// Trung tâm điều khiển: bật ra từ góc phải trên khi bấm cụm trạng thái trên thanh.
PanelWindow {
    id: win

    anchors { top: true; right: true }
    margins { top: 50; right: 12 }
    implicitWidth: 340
    implicitHeight: 560
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: true

    WlrLayershell.namespace: "islet-cc"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool open: Ui.controlCenterOpen
    // Giữ cửa sổ sống trong lúc chạy animation đóng.
    visible: open || panel.opacity > 0.01

    mask: Region { item: panel }

    // Bấm ra ngoài thì đóng.
    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Ui.controlCenterOpen = false
    }

    readonly property var bt: Bluetooth.defaultAdapter

    Glass {
        id: panel
        width: parent.width
        height: content.implicitHeight + 28
        radius: 28
        color: Theme.surface(0.55)

        transformOrigin: Item.TopRight
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.86
        Behavior on opacity { NumberAnimation { duration: win.open ? 180 : 140; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4.2; damping: 0.3; epsilon: 0.002 } }

        Keys.onEscapePressed: Ui.controlCenterOpen = false
        focus: win.open

        Column {
            id: content
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 12

            // Hai ô bật/tắt
            Row {
                width: parent.width
                spacing: 12

                Tile {
                    width: (parent.width - 12) / 2
                    icon: Net.icon
                    title: Net.kind === "ethernet" ? "Network" : "Wi-Fi"
                    subtitle: Net.label
                    checked: Net.connected
                    available: Net.wifiPresent || Net.connected
                    onToggled: if (Net.wifiPresent) Net.toggleWifi()
                }
                Tile {
                    width: (parent.width - 12) / 2
                    icon: "bluetooth"
                    title: "Bluetooth"
                    subtitle: !win.bt ? "None" : win.bt.enabled ? "On" : "Off"
                    checked: win.bt?.enabled ?? false
                    available: win.bt !== null
                    onColor: Theme.violet
                    onToggled: if (win.bt) win.bt.enabled = !win.bt.enabled
                }
            }

            // Night Light · Tiết kiệm pin
            Row {
                width: parent.width
                spacing: 12
                Tile {
                    width: (parent.width - 12) / 2
                    icon: "moon"
                    title: "Night Light"
                    subtitle: NightLight.active ? (Prefs.nightMode === "schedule" ? "Until " + Prefs.nightTo : "On") : Prefs.nightMode === "schedule" ? "From " + Prefs.nightFrom : "Off"
                    checked: NightLight.active
                    onColor: "#FFB547"
                    onToggled: NightLight.toggle()
                }
                Tile {
                    width: (parent.width - 12) / 2
                    icon: "bolt"
                    title: "Battery saver"
                    subtitle: PowerProfiles.profile === PowerProfile.PowerSaver ? "On" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"
                    checked: PowerProfiles.profile === PowerProfile.PowerSaver
                    onColor: "#34C77B"
                    onToggled: PowerProfiles.profile = checked ? PowerProfile.Balanced : PowerProfile.PowerSaver
                }
            }

            Tile {
                width: parent.width
                icon: "moon"
                title: "Focus"
                subtitle: Ui.focusMode ? "On — no banners, desktop hidden" : "Silence banners, hide the desktop, dim the rest"
                checked: Ui.focusMode
                onColor: Theme.violet
                onToggled: Ui.focusMode = !Ui.focusMode
            }

            Slider {
                width: parent.width
                title: "Volume"
                value: Audio.muted ? 0 : Math.min(1, Audio.volume)
                available: Audio.sink !== null
                onMoved: v => Audio.setVolume(v)
            }

            Slider {
                width: parent.width
                title: "Brightness"
                value: Brightness.value
                fill: Theme.amber
                available: Brightness.available
                visible: Brightness.available
                onMoved: v => Brightness.set(v)
            }

            // Mini player
            Rectangle {
                width: parent.width
                height: 72
                radius: 18
                color: Theme.fg(0.10)
                visible: Media.hasPlayer

                Artwork {
                    id: art
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    radius: 12
                    source: Media.artUrl
                }
                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 12
                    anchors.right: controls.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: Media.title
                        color: Theme.label
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Media.artist
                        color: Theme.fg(0.68)
                        font.family: Theme.font
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    IconButton {
                        implicitWidth: 38; implicitHeight: 38; iconSize: 18
                        icon: Qt.resolvedUrl(Media.playing ? "../assets/icons/pause.svg" : "../assets/icons/play.svg")
                        fill: Theme.label
                        onClicked: Media.toggle()
                    }
                    IconButton {
                        implicitWidth: 38; implicitHeight: 38; iconSize: 18
                        icon: Qt.resolvedUrl("../assets/icons/next.svg")
                        active: Media.active?.canGoNext ?? false
                        onClicked: Media.next()
                    }
                }
            }

            // Chân: logo + tên máy
            Item {
                width: parent.width
                height: 28
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Image {
                        width: 20; height: 20
                        sourceSize: Qt.size(40, 40)
                        source: Qt.resolvedUrl("../assets/icons/islet.svg")
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Islet"
                        color: Theme.fg(0.68)
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
                Text {
                    anchors.right: gear.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Time.dateLong
                    color: Theme.fg(0.42)
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                // mở app Cài đặt
                Rectangle {
                    id: gear
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 14
                    color: gm.containsMouse ? Theme.fg(0.2) : Theme.fg(0.1)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    TIcon {
                        anchors.centerIn: parent; name: "settings"; size: 15
                        rotation: gm.containsMouse ? 60 : 0
                        Behavior on rotation { SpringAnimation { spring: 3; damping: 0.3 } }
                    }
                    MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.openSettings("") }
                }
            }
        }
    }
}
