import QtQuick
import QtQuick.Effects

// Icon SVG, tô lại được màu bất kỳ (icon gốc vẽ màu trắng).
Item {
    id: root

    property string name: ""
    property real size: 18
    property color color: "#FFFFFF"
    readonly property bool tinted: !Qt.colorEqual(color, "#FFFFFF")

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? Qt.resolvedUrl("../assets/icons/" + root.name + ".svg") : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
        visible: !root.tinted
    }

    MultiEffect {
        anchors.fill: img
        source: img
        visible: root.tinted
        colorization: 1
        colorizationColor: root.color
        brightness: 1
    }
}
