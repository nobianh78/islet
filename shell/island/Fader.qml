import QtQuick

// Chuyển màn trong island (chuyển từ _setView): màn cũ mờ + thu về 0.94 trong 140 ms,
// màn mới đợi 90 ms rồi nở từ 0.92 lên 1 trong 360 ms. Neo ở giữa mép trên.
Item {
    id: root

    property bool shown: false

    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    transformOrigin: Item.Top
    visible: opacity > 0.01

    opacity: shown ? 1 : 0
    scale: shown ? 1 : (fadingIn ? 0.92 : 0.94)
    property bool fadingIn: false
    onShownChanged: fadingIn = shown

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.shown ? 90 : 0 }
            NumberAnimation { duration: root.shown ? 360 : 140; easing.type: root.shown ? Easing.OutCubic : Easing.OutQuad }
        }
    }
    Behavior on scale {
        SequentialAnimation {
            PauseAnimation { duration: root.shown ? 90 : 0 }
            NumberAnimation { duration: root.shown ? 360 : 140; easing.type: root.shown ? Easing.OutCubic : Easing.OutQuad }
        }
    }
}
