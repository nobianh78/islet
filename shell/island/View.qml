import QtQuick
import QtQuick.Effects
import "../theme"

// Một "màn" nội dung bên trong island. Khi đổi màn, nội dung cũ mờ + nhoè đi,
// nội dung mới hiện ra sau một nhịp ngắn, nên trông như khung đang biến hình.
Item {
    id: root

    property bool shown: false

    anchors.centerIn: parent
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.9
    visible: opacity > 0.01

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.shown ? Theme.fadeDelay : 0 }
            NumberAnimation {
                duration: root.shown ? Theme.fadeIn : Theme.fadeOut
                easing.type: Easing.OutCubic
            }
        }
    }
    Behavior on scale {
        SequentialAnimation {
            PauseAnimation { duration: root.shown ? Theme.fadeDelay : 0 }
            SpringAnimation { spring: 4; damping: 0.36 }
        }
    }

    layer.enabled: opacity > 0.01 && opacity < 0.99
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 24
        blur: 1 - root.opacity
    }
}
