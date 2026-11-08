import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Displays (phần thêm): sắp xếp nhiều màn hình (kéo thả), xoay, tần số quét.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property var monitors: []
    signal apply(string name, var patch)

    // ---- sắp xếp (chỉ khi có từ 2 màn hình) ----
    SectionLabel { text: "Arrangement"; visible: page.monitors.length > 1 }
    Card {
        id: arr
        visible: page.monitors.length > 1
        width: parent.width; height: 220
        readonly property var box: {
            let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
            for (const m of page.monitors) { const w = m.width / m.scale, h = m.height / m.scale; x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + w); y1 = Math.max(y1, m.y + h); }
            const k = Math.min((arr.width - 60) / Math.max(1, x1 - x0), (arr.height - 50) / Math.max(1, y1 - y0));
            return { x0: x0, y0: y0, k: k, ox: (arr.width - (x1 - x0) * k) / 2, oy: (arr.height - (y1 - y0) * k) / 2 };
        }
        Repeater {
            model: page.monitors
            Rectangle {
                id: mb
                required property var modelData
                readonly property real lw: modelData.width / modelData.scale
                readonly property real lh: modelData.height / modelData.scale
                x: arr.box.ox + (modelData.x - arr.box.x0) * arr.box.k
                y: arr.box.oy + (modelData.y - arr.box.y0) * arr.box.k
                width: lw * arr.box.k; height: lh * arr.box.k; radius: 8
                color: dh.active ? Theme.tint(0.35) : Theme.tint(0.2)
                border.width: 2; border.color: Theme.accent
                Text { anchors.centerIn: parent; text: mb.modelData.name + "\n" + mb.modelData.width + "×" + mb.modelData.height; horizontalAlignment: Text.AlignHCenter; color: Theme.label; font.family: Theme.font; font.pixelSize: 11 }
                DragHandler {
                    id: dh
                    onActiveChanged: if (!active) {
                        // vị trí mới (toạ độ thật), hít vào mép màn hình khác
                        let nx = Math.round(arr.box.x0 + (mb.x - arr.box.ox) / arr.box.k), ny = Math.round(arr.box.y0 + (mb.y - arr.box.oy) / arr.box.k);
                        for (const o of page.monitors) {
                            if (o.name === mb.modelData.name) continue;
                            const ow = o.width / o.scale, oh = o.height / o.scale;
                            const cands = [[o.x + ow, ny], [o.x - mb.lw, ny], [nx, o.y + oh], [nx, o.y - mb.lh]];
                            let best = null, bd = 1e9;
                            for (const c of cands) { const d = Math.hypot(c[0] - nx, c[1] - ny); if (d < bd) { bd = d; best = c; } }
                            if (best && bd < 400) { nx = best[0]; ny = best[1]; if (Math.abs(ny - o.y) < 120) ny = o.y; if (Math.abs(nx - o.x) < 120) nx = o.x; }
                        }
                        page.apply(mb.modelData.name, { pos: [nx, ny] });
                    }
                }
            }
        }
        Text { x: 14; y: 10; text: "Drag the screens to match how they sit on your desk"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
    }

    Repeater {
        model: page.monitors
        Card {
            id: mc
            required property var modelData
            width: page.width
            height: mcCol.implicitHeight + 28
            readonly property string res: modelData.width + "x" + modelData.height
            readonly property var rates: {
                const out = [];
                for (const m of (modelData.availableModes || [])) {
                    const r = m.match(/^(\d+x\d+)@([\d.]+)/);
                    if (r && r[1] === mc.res) { const hz = Math.round(parseFloat(r[2])); if (out.indexOf(hz) < 0) out.push(hz); }
                }
                return out.sort((a, b) => b - a);
            }
            Column {
                id: mcCol
                x: 18; y: 14; width: parent.width - 36; spacing: 10
                Text { text: mc.modelData.name + " · " + mc.res + " @ " + Math.round(mc.modelData.refreshRate) + " Hz"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                Row {
                    spacing: 6
                    visible: mc.rates.length > 1
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Refresh rate"; width: 100; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                    Repeater { model: mc.rates; Chip { required property int modelData; label: modelData + " Hz"; on: Math.round(mc.modelData.refreshRate) === modelData; onClicked: page.apply(mc.modelData.name, { mode: mc.res + "@" + modelData }) } }
                }
                Row {
                    spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Rotation"; width: 100; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                    Repeater {
                        model: [[0, "Normal"], [1, "90°"], [2, "180°"], [3, "270°"]]
                        Chip { required property var modelData; label: modelData[1]; on: (mc.modelData.transform || 0) === modelData[0]; onClicked: page.apply(mc.modelData.name, { transform: modelData[0] }) }
                    }
                }
            }
        }
    }
}
