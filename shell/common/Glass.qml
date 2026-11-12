import QtQuick
import "../theme"

// Khung kính mờ như trong thiết kế. Phần nhoè phía sau do Hyprland lo (layer_rule blur).
Rectangle {
    color: Theme.light ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0.04, 0.04, 0.07, 0.28)
    border.color: Qt.rgba(1, 1, 1, 0.18 + 0.22 * Prefs.glass)
    border.width: 1
    radius: 24

    // ánh sáng từ trên xuống (liquid glass); lớp này nằm dưới nội dung của từng bảng
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.14 * Prefs.glass) }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }
}
