import QtQuick

// Lò xo vật lý (chuyển từ lib/anim.js Spring): đổi đích giữa chừng vẫn giữ vận tốc,
// nên animation bị ngắt không bao giờ giật.
Item {
    id: s
    visible: false

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real stiffness: 300
    property real dampingRatio: 0.74
    readonly property real c: 2 * dampingRatio * Math.sqrt(stiffness)
    readonly property bool moving: anim.running

    function jump(v) { value = v; velocity = 0; }

    Component.onCompleted: value = target
    onTargetChanged: anim.running = true

    FrameAnimation {
        id: anim
        onTriggered: {
            const dt = Math.min(0.05, frameTime);
            const steps = Math.max(1, Math.ceil(dt * 240));
            const h = dt / steps;
            let x = s.value, v = s.velocity;
            for (let i = 0; i < steps; i++) {
                const a = -s.stiffness * (x - s.target) - s.c * v;
                v += a * h;
                x += v * h;
            }
            if (Math.abs(x - s.target) < 0.25 && Math.abs(v) < 3) {
                x = s.target; v = 0;
                running = false;
            }
            s.velocity = v;
            s.value = x;
        }
    }
}
