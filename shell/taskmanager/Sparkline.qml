import QtQuick
import "../theme"

// Biểu đồ đường mượt có tô gradient bên dưới. values: mảng số; max: trần (0 = tự co giãn).
Canvas {
    id: root

    property var values: []
    property var values2: []          // đường thứ hai (vd. tải lên)
    property real max: 100
    property color color: Theme.violet
    property color color2: "#FF6B97"
    property int slots: 60

    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onWidthChanged: requestPaint()

    function ceiling() {
        if (max > 0) return max;
        let m = 1;
        for (const v of values) m = Math.max(m, v);
        for (const v of values2) m = Math.max(m, v);
        return m * 1.15;
    }

    function line(ctx, vals, c, fill) {
        if (!vals || vals.length < 2) return;
        const m = ceiling();
        const step = width / (slots - 1);
        const x0 = width - (vals.length - 1) * step;
        const pt = i => [x0 + i * step, height - 2 - (Math.min(m, vals[i]) / m) * (height - 6)];
        ctx.beginPath();
        let p = pt(0);
        ctx.moveTo(p[0], p[1]);
        for (let i = 1; i < vals.length; i++) {
            const q = pt(i);
            const mx = (p[0] + q[0]) / 2;
            ctx.bezierCurveTo(mx, p[1], mx, q[1], q[0], q[1]);
            p = q;
        }
        ctx.strokeStyle = c;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.stroke();
        if (fill) {
            ctx.lineTo(width, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.35));
            g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
            ctx.fillStyle = g;
            ctx.fill();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        // vạch lưới mảnh
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06);
        ctx.lineWidth = 1;
        for (let i = 1; i < 4; i++) {
            ctx.beginPath();
            ctx.moveTo(0, Math.round(height * i / 4) + 0.5);
            ctx.lineTo(width, Math.round(height * i / 4) + 0.5);
            ctx.stroke();
        }
        line(ctx, values2, color2, true);
        line(ctx, values, color, true);
    }
}
