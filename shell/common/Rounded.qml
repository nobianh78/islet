import QtQuick
import QtQuick.Effects

// Cắt nội dung theo khung bo góc (Item thường không tự bo được con của nó).
Item {
    id: root
    property real radius: 12
    default property alias content: inner.data

    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}
