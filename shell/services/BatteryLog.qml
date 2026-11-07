pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Ghi mức pin mỗi 5 phút (24 giờ gần nhất) cho biểu đồ ở Cài đặt › Power & Battery.
Singleton {
    id: root
    property var points: []     // { t, p (0..1), c (đang sạc) }
    readonly property string file: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/islet/battery.json"
    readonly property bool present: UPower.displayDevice?.isLaptopBattery ?? false
    function sample() {
        if (!present) return;
        const now = Date.now();
        points = points.filter(x => now - x.t < 24 * 3600 * 1000).concat([{ t: now, p: UPower.displayDevice.percentage, c: !UPower.onBattery }]);
        store.setText(JSON.stringify(points));
    }
    Timer { interval: 5 * 60 * 1000; running: root.present; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }
    FileView {
        id: store
        path: root.file
        blockLoading: false
        onLoaded: { try { const d = JSON.parse(text()); if (Array.isArray(d)) root.points = d; } catch (e) {} }
    }
}
