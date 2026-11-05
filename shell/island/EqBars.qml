import QtQuick

// Thanh sóng nhạc mượt (chuyển từ lib/anim.js Equalizer); tạm dừng thì dẹp thành chấm.
Canvas {
    id: eq

    property bool playing: true
    property color color: "#30D158"
    property int bars: 4

    implicitWidth: 22
    implicitHeight: 18
    renderStrategy: Canvas.Cooperative

    property real amp: 1
    property real t0: Date.now() / 1000

    Timer {
        interval: 33
        repeat: true
        running: eq.visible
        onTriggered: eq.requestPaint()
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const t = Date.now() / 1000 - t0;
        amp += ((playing ? 1 : 0.12) - amp) * 0.12;
        const n = bars, w = width, h = height;
        const bw = Math.max(2, w / (n * 1.9));
        const gap = (w - bw * n) / (n - 1);
        ctx.strokeStyle = color;
        ctx.lineWidth = bw;
        ctx.lineCap = "round";
        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const wave = Math.abs(Math.sin(t * (2.1 + i * 0.73) + i * 1.9)) * 0.65 +
                Math.abs(Math.sin(t * (3.7 - i * 0.4) + i)) * 0.35;
            const v = 0.18 + 0.82 * wave * amp;
            const x = bw / 2 + i * (bw + gap);
            const half = (h - bw) * v / 2;
            ctx.moveTo(x, h / 2 - half);
            ctx.lineTo(x, h / 2 + half);
        }
        ctx.stroke();
    }
}
