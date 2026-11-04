pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Pin qua UPower. Phát `plugged` khi vừa cắm sạc.
Singleton {
    id: root

    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property bool present: dev?.isLaptopBattery ?? false
    // Quickshell trả về 0..1; phòng trường hợp bản cũ trả 0..100.
    readonly property real percent: {
        const p = dev?.percentage ?? 0;
        return p > 1 ? p : p * 100;
    }
    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging: present && !onBattery

    signal plugged()

    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: root.armed = true }

    onOnBatteryChanged: if (armed && present && !onBattery) plugged()
}
