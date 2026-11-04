import QtQuick

// Đôi mắt mèo Islet: lúc rảnh island chính là cái mặt nạ của logo.
// Thỉnh thoảng chớp mắt, liếc qua lại, và híp mắt cười khi được trỏ chuột vào.
Item {
    id: root

    property bool happy: false
    property real eye: 8
    property real gap: 36

    property real blink: 1
    property real look: 0

    implicitWidth: gap + eye
    implicitHeight: eye

    Behavior on look { SpringAnimation { spring: 4; damping: 0.35 } }

    Repeater {
        model: 2
        Rectangle {
            required property int index
            width: root.eye
            height: root.eye
            radius: root.eye / 2
            color: "#FFFFFF"
            x: (index === 0 ? 0 : root.gap) + root.look
            y: root.happy ? -1.5 : 0
            Behavior on y { SpringAnimation { spring: 5; damping: 0.4 } }

            transform: Scale {
                origin.x: root.eye / 2
                origin.y: root.eye / 2
                yScale: root.happy ? 0.38 : root.blink
                Behavior on yScale { enabled: root.happy || root.blink === 1; SpringAnimation { spring: 6; damping: 0.45 } }
            }
        }
    }

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "blink"; to: 0.1; duration: 70; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 120; easing.type: Easing.OutQuad }
    }
    SequentialAnimation {
        id: doubleBlink
        NumberAnimation { target: root; property: "blink"; to: 0.1; duration: 60 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 90 }
        PauseAnimation { duration: 90 }
        NumberAnimation { target: root; property: "blink"; to: 0.1; duration: 60 }
        NumberAnimation { target: root; property: "blink"; to: 1; duration: 110 }
    }

    Timer {
        running: root.visible && !root.happy
        repeat: true
        interval: 3000
        onTriggered: {
            interval = 2400 + Math.random() * 4200;
            if (Math.random() < 0.2) doubleBlink.restart(); else blinkAnim.restart();
        }
    }

    Timer {
        running: root.visible && !root.happy
        repeat: true
        interval: 5000
        onTriggered: {
            interval = 3500 + Math.random() * 5000;
            const r = Math.random();
            root.look = r < 0.3 ? -3 : r < 0.6 ? 3 : 0;
        }
    }

    onHappyChanged: if (happy) look = 0
}
