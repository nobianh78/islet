import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Vầng sáng nhiều màu chạy quanh island (kiểu viền Siri). `soft` = bản nhoè làm quầng sáng.
// Hình dạng khớp island: phẳng ở trên, bo hai góc dưới.
Item {
    id: root
    property real r: 22
    property real spin: 0
    property bool soft: false

    layer.enabled: soft
    layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                angle: root.spin
                GradientStop { position: 0.00; color: "#8B7CFF" }
                GradientStop { position: 0.25; color: "#FF6B97" }
                GradientStop { position: 0.50; color: "#FFB547" }
                GradientStop { position: 0.75; color: "#2DD4BF" }
                GradientStop { position: 1.00; color: "#8B7CFF" }
            }
            PathSvg {
                path: "M 0 0 L " + root.width + " 0 L " + root.width + " " + (root.height - root.r)
                    + " A " + root.r + " " + root.r + " 0 0 1 " + (root.width - root.r) + " " + root.height
                    + " L " + root.r + " " + root.height
                    + " A " + root.r + " " + root.r + " 0 0 1 0 " + (root.height - root.r) + " Z"
            }
        }
    }
}
