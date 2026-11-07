import QtQuick
import "../theme"
import "../common"

// Một icon trong dock của Islet.
//   rê chuột  : nhấc lên + nghiêng 3D nhẹ theo con trỏ (không đẩy icon khác, nên rất mượt)
//   bấm       : dẻo như thạch + vòng sóng lan ra màu của app
//   đang chạy : viên thuốc nhỏ bên dưới, dài ra khi app đang được dùng
Item {
    id: root

    property string label: ""
    property string icon: ""
    property string iconUrl: ""        // icon app bất kỳ (khi không có icon Islet riêng)
    property bool menuOpen: false
    property color tile: Theme.violet
    readonly property color glow: Prefs.iconStyle === "color" ? tile : Theme.accent
    property bool running: false
    property bool focused: false
    property bool minimized: false     // mọi cửa sổ của app đang thu nhỏ
    property real base: 46
    property int order: 0
    property real pointer: -1000      // toạ độ chuột so với tâm icon; -1000 = không rê

    property bool playIntro: true      // bật lên lúc shell khởi động (không lặp lại khi dock dựng lại)
    property bool draggable: false     // app ghim / đang chạy: kéo để đổi chỗ, kéo lên để bỏ ghim
    property bool dragging: false

    signal activated()
    signal contextRequested()
    signal dragStarted()
    signal dragMoved(real sceneX, real dy)
    signal dragEnded()

    readonly property bool hovered: mouse.containsMouse || menuOpen

    width: base
    height: base

    // ---------------- Thân icon ----------------
    Item {
        id: body
        width: root.base
        height: root.base

        // Trạng thái hover: nhấc lên + phóng nhẹ + nghiêng theo con trỏ.
        property real lift: root.hovered ? -6 : 0
        property real grow: root.hovered ? 1.07 : 1
        property real tilt: root.hovered ? Math.max(-1, Math.min(1, root.pointer / (root.base / 2))) * 9 : 0
        Behavior on lift { SpringAnimation { spring: 4.5; damping: 0.32; epsilon: 0.05 } }
        Behavior on grow { SpringAnimation { spring: 4.5; damping: 0.32; epsilon: 0.002 } }
        Behavior on tilt { SpringAnimation { spring: 3.5; damping: 0.4; epsilon: 0.05 } }

        // Thạch: co giãn ngược chiều nhau khi bấm / mở app.
        property real squashX: 1
        property real squashY: 1

        // Bật lên lúc shell khởi động.
        property real intro: 0

        transform: [
            Rotation {
                origin.x: root.base / 2
                origin.y: root.base / 2
                axis { x: 0; y: 1; z: 0 }
                angle: body.tilt
            },
            Scale {
                origin.x: root.base / 2
                origin.y: root.base
                xScale: body.grow * body.squashX * body.intro
                yScale: body.grow * body.squashY * body.intro
            },
            Translate { y: body.lift + (1 - body.intro) * 18 }
        ]

        // Icon app (shell/assets/apps/*.svg, vẽ bằng scripts/make-icons.py).
        // SVG chừa lề 6/128 cho bóng, nên vẽ to hơn một chút để phần squircle đúng bằng base.
        Item {
            id: tileRect
            anchors.fill: parent

            AppIcon {
                anchors.centerIn: parent
                size: root.base
                name: root.icon
                source: root.iconUrl
            }

            // Ánh sáng chạy ngang mặt icon theo hướng nghiêng.
            Rectangle {
                anchors.fill: parent
                radius: root.base * 0.27
                opacity: root.hovered ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, body.tilt < 0 ? 0.20 : 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, body.tilt > 0 ? 0.20 : 0) }
                }
            }
        }
    }

    // ---------------- Vòng sóng khi mở app ----------------
    Rectangle {
        id: ripple
        anchors.centerIn: parent
        width: root.base
        height: root.base
        radius: root.base * 0.3
        color: "transparent"
        border.width: 2
        border.color: Qt.lighter(root.glow, 1.3)
        opacity: 0
        scale: 1
    }

    // ---------------- Chỉ báo đang chạy ----------------
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 3
        height: 3
        radius: 1.5
        // Thu nhỏ: viên rỗng (chỉ viền); đang dùng: viên dài màu app; đang chạy: chấm trắng.
        width: !root.running ? 0 : root.focused ? 16 : root.minimized ? 8 : 5
        opacity: root.running ? 1 : 0
        color: root.minimized ? "transparent" : root.focused ? Qt.lighter(root.glow, 1.35) : Qt.rgba(1, 1, 1, 0.7)
        border.width: root.minimized ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.7)
        Behavior on width { SpringAnimation { spring: 4.5; damping: 0.3; epsilon: 0.05 } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // ---------------- Animation ----------------
    ParallelAnimation {
        id: jelly
        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation { target: body; property: "squashX"; to: 1.16; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: body; property: "squashY"; to: 0.82; duration: 90; easing.type: Easing.OutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: body; property: "squashX"; to: 0.92; duration: 120; easing.type: Easing.InOutQuad }
                NumberAnimation { target: body; property: "squashY"; to: 1.1; duration: 120; easing.type: Easing.InOutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: body; property: "squashX"; to: 1; duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 }
                NumberAnimation { target: body; property: "squashY"; to: 1; duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 }
            }
        }
        SequentialAnimation {
            PropertyAction { target: ripple; property: "opacity"; value: 0.9 }
            PropertyAction { target: ripple; property: "scale"; value: 1 }
            ParallelAnimation {
                NumberAnimation { target: ripple; property: "scale"; to: 1.7; duration: 650; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: 650; easing.type: Easing.OutCubic }
            }
        }
    }

    // Cửa sổ vừa thu nhỏ "rơi" vào icon: icon lún xuống rồi bật lại.
    function receive() { receiveAnim.restart(); }
    SequentialAnimation {
        id: receiveAnim
        ParallelAnimation {
            NumberAnimation { target: body; property: "squashX"; to: 1.12; duration: 130; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "squashY"; to: 0.78; duration: 130; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: body; property: "squashX"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
            NumberAnimation { target: body; property: "squashY"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
        }
    }

    SequentialAnimation {
        id: introAnim
        PauseAnimation { duration: 120 + root.order * 70 }
        NumberAnimation { target: body; property: "intro"; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
    Component.onCompleted: { if (playIntro) introAnim.start(); else body.intro = 1; }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property point press: Qt.point(0, 0)
        property bool eatClick: false
        onPressed: m => {
            eatClick = false;
            if (m.button === Qt.RightButton) return;
            press = mapToItem(null, m.x, m.y);
            body.squashX = 1.06;
            body.squashY = 0.92;
        }
        onPositionChanged: m => {
            if (!pressed || !root.draggable || (m.buttons & Qt.LeftButton) === 0) return;
            const p = mapToItem(null, m.x, m.y);
            if (!root.dragging && (Math.abs(p.x - press.x) > 6 || Math.abs(p.y - press.y) > 6)) {
                root.dragging = true;
                body.squashX = 1; body.squashY = 1;
                root.dragStarted();
            }
            if (root.dragging) root.dragMoved(p.x, p.y - press.y);
        }
        onReleased: { if (root.dragging) { root.dragging = false; eatClick = true; root.dragEnded(); } }
        onCanceled: { body.squashX = 1; body.squashY = 1; if (root.dragging) { root.dragging = false; root.dragEnded(); } }
        onClicked: m => {
            if (eatClick) { eatClick = false; return; }
            if (m.button === Qt.RightButton) { root.contextRequested(); return; }
            jelly.restart();
            root.activated();
        }
    }
}
