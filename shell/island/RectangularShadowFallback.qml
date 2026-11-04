import QtQuick
import QtQuick.Effects

// Bóng đổ cho island. Dùng MultiEffect để chạy được trên Qt 6.5 trở lên.
Item {
    id: root
    property real radius: 18

    Rectangle {
        id: src
        anchors.fill: parent
        radius: root.radius
        color: "black"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        source: src
        anchors.fill: src
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowBlur: 1.0
        shadowVerticalOffset: 10
        shadowHorizontalOffset: 0
        blurMax: 48
        autoPaddingEnabled: true
    }
}
