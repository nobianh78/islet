import QtQuick
import Quickshell.Bluetooth
import "../theme"
import "../common"

// Bluetooth nhanh: bật/tắt, tìm thiết bị, bấm để nối / ngắt / ghép đôi.
QuickPanel {
    id: root
    title: "Bluetooth"
    readonly property var bt: Bluetooth.defaultAdapter
    on: bt?.enabled ?? false
    showSwitch: bt !== null
    onSwitched: if (bt) bt.enabled = !bt.enabled

    Component.onCompleted: if (bt && bt.enabled) bt.discovering = true
    Component.onDestruction: if (bt && bt.discovering) bt.discovering = false

    readonly property var devices: (bt?.devices?.values ?? []).slice().sort((a, b) =>
        (b.connected - a.connected) || (b.paired - a.paired) || ((a.name || "").localeCompare(b.name || ""))).slice(0, 7)

    Text {
        visible: !root.bt
        text: "No Bluetooth adapter"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    Text {
        visible: root.bt && !root.bt.enabled
        text: "Bluetooth is off"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    Text {
        visible: root.bt && root.bt.enabled && root.devices.length === 0
        width: parent.width; wrapMode: Text.WordWrap
        text: "Looking for devices… put your headphones or mouse in pairing mode"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    Repeater {
        model: root.bt && root.bt.enabled ? root.devices : []
        Glass {
            id: dev
            required property var modelData
            readonly property bool busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
            width: parent.width; height: 40; radius: 20
            color: dm.containsMouse ? Theme.glassHover : Theme.glassFill
            TIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "bluetooth"; size: 16 }
            Column {
                x: 38; width: parent.width - 38 - 14
                anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; elide: Text.ElideRight; text: dev.modelData.name || dev.modelData.address; color: Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: dev.modelData.pairing ? "Pairing…" : dev.busy ? "Connecting…" : dev.modelData.connected ? "Connected" : dev.modelData.paired ? "Paired" : "Tap to pair"
                    color: dev.modelData.connected ? Theme.accent : Theme.muted; font.family: Theme.font; font.pixelSize: 10
                }
            }
            MouseArea {
                id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const d = dev.modelData;
                    if (dev.busy) return;
                    if (d.connected) d.disconnect();
                    else if (d.paired) d.connect();
                    else { d.trusted = true; d.pair(); }
                }
            }
        }
    }
}
