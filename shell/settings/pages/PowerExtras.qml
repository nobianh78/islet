import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
import Quickshell.Services.UPower
// Cài đặt › Power & Battery (phần thêm): biểu đồ pin 24 giờ, sức khoẻ pin, giới hạn sạc.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property var health: null           // { pct, cycles }
    property bool canLimit: false
    property int limit: 100
    property string msg: ""
    visible: Power.present
    onVisibleChanged: if (visible) bat.running = true
    Process {
        id: bat
        command: ["sh", "-c", 'for b in /sys/class/power_supply/BAT*; do [ -d "$b" ] || continue; f=$(cat $b/energy_full 2>/dev/null || cat $b/charge_full 2>/dev/null); d=$(cat $b/energy_full_design 2>/dev/null || cat $b/charge_full_design 2>/dev/null); c=$(cat $b/cycle_count 2>/dev/null || echo 0); l=$(cat $b/charge_control_end_threshold 2>/dev/null || echo -); echo "$f $d $c $l"; break; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (p.length < 4) return;
                page.health = (+p[1] > 0) ? { pct: Math.round(+p[0] * 100 / +p[1]), cycles: +p[2] } : null;
                page.canLimit = p[3] !== "-"; if (page.canLimit) page.limit = +p[3];
            }
        }
    }

    SectionLabel { text: "Battery level · last 24 hours" }
    Card {
        width: parent.width; height: 150
        Canvas {
            id: chart
            anchors.fill: parent; anchors.margins: 16
            readonly property var pts: BatteryLog.points
            onPtsChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset();
                const W = width, H = height - 14, now = Date.now(), t0 = now - 24 * 3600 * 1000;
                c.strokeStyle = Qt.rgba(1, 1, 1, 0.08); c.lineWidth = 1;
                for (const f of [0, 0.5, 1]) { c.beginPath(); c.moveTo(0, H * f); c.lineTo(W, H * f); c.stroke(); }
                if (pts.length < 2) return;
                const X = t => (t - t0) / (now - t0) * W, Y = p => H - p * H;
                const grad = c.createLinearGradient(0, 0, 0, H); grad.addColorStop(0, Theme.tint(0.45)); grad.addColorStop(1, Theme.tint(0));
                c.beginPath(); c.moveTo(X(pts[0].t), H);
                for (const p of pts) c.lineTo(X(p.t), Y(p.p));
                c.lineTo(X(pts[pts.length - 1].t), H); c.closePath(); c.fillStyle = grad; c.fill();
                c.beginPath(); c.lineWidth = 2; c.strokeStyle = Theme.accent;
                pts.forEach((p, i) => i ? c.lineTo(X(p.t), Y(p.p)) : c.moveTo(X(p.t), Y(p.p))); c.stroke();
                // đoạn đang sạc
                c.fillStyle = "#34C77B";
                for (const p of pts) if (p.c) c.fillRect(X(p.t) - 1, H + 6, 3, 4);
            }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: "green = charging"; color: "#636366"; font.family: Theme.font; font.pixelSize: 10 }
    }

    Card {
        visible: page.health !== null
        width: parent.width; height: 64
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Battery health · " + (page.health?.pct ?? 0) + "%"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: (page.health?.pct ?? 0) >= 80 ? "Holds most of its original charge" + (page.health?.cycles ? " · " + page.health.cycles + " charge cycles" : "") : "Holds noticeably less than when new — consider a replacement"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
        }
    }
    Card {
        visible: page.canLimit
        width: parent.width; height: 74
        Text { x: 18; y: 14; text: "Limit charging to protect the battery"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        Row {
            x: 18; y: 38; spacing: 6
            Repeater {
                model: [[60, "60%"], [80, "80% (recommended when plugged in a lot)"], [100, "Full"]]
                Chip { required property var modelData; label: modelData[1]; on: page.limit === modelData[0]; onClicked: Admin.run(["charge-limit", String(modelData[0])], (ok, out) => { page.msg = ok ? "" : out; bat.running = true; }) }
            }
        }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }
}
