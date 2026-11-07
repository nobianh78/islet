import QtQuick
import QtQuick.Effects
import "../theme"

// Hình nền Islet vẽ trong một Item (dùng cho màn hình nền, màn hình khoá, ô xem trước trong Cài đặt).
//   preset: bộ màu đốm (mặc định Prefs.preset) · image: đường dẫn ảnh ("" = dùng đốm màu)
Item {
    id: root
    property var preset: Prefs.preset
    property string image: Prefs.wallpaperIsImage ? Prefs.wallpaperEff : ""
    property bool animated: true
    clip: true

    Rectangle {
        anchors.fill: parent
        color: root.preset.base
        Behavior on color { ColorAnimation { duration: 900; easing.type: Easing.InOutCubic } }
    }

    readonly property real k: 4   // hệ số thu nhỏ

    Item {
        id: canvas
        width: root.width / root.k
        height: root.height / root.k
        transformOrigin: Item.TopLeft
        scale: root.k
        // Mỗi đốm được làm mờ MỘT lần thành ảnh đệm riêng (layer bên dưới); lúc trôi chỉ dời ảnh
        // đã mờ, không phải làm mờ lại cả màn hình mỗi khung → nhẹ CPU/GPU hơn hẳn.
        readonly property int blurPx: Math.max(8, Math.min(64, Math.round(canvas.width / 5.6)))

        // [x, y, đường kính, chu kỳ ms] theo tỉ lệ màn hình 1440×900; màu + độ đậm lấy từ Prefs.preset
        Repeater {
            model: [
                [-140, -120, 720, 14000],
                [ 900,  120, 640, 18000],
                [ 360,  620, 780, 16000]
            ]

            Rectangle {
                id: blob
                required property var modelData
                required property int index
                readonly property real sx: canvas.width / 360
                readonly property real sy: canvas.height / 225

                // trôi theo đồng hồ chung (Drift.t), giống nhau ở mọi nơi vẽ hình nền
                readonly property real tt: root.animated ? Drift.t : 0
                readonly property real dx: 10 * (blob.index % 2 ? -1 : 1) * (1 - Math.cos(2 * Math.PI * tt * 1000 / modelData[3])) / 2
                readonly property real dy: 7.5 * (1 - Math.cos(2 * Math.PI * tt * 1000 / (modelData[3] * 1.13))) / 2

                width: modelData[2] / 4 * sx
                height: width
                radius: width / 2
                color: root.preset.blobs[index][0]
                opacity: root.preset.blobs[index][1]
                Behavior on color { ColorAnimation { duration: 900; easing.type: Easing.InOutCubic } }
                Behavior on opacity { NumberAnimation { duration: 900 } }
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: canvas.blurPx
                    blur: 1
                    saturation: 0.1
                    autoPaddingEnabled: true
                }
                x: modelData[0] / 4 * sx + dx
                y: modelData[1] / 4 * sy + dy

            }
        }
    }

    // Ảnh nền (hai lớp để mờ dần khi đổi ảnh)
    property bool flip: false
    readonly property string imageSrc: root.image ? "file://" + root.image : ""
    onImageSrcChanged: { flip = !flip; (flip ? imgA : imgB).source = imageSrc; }
    Component.onCompleted: if (imageSrc) { flip = true; imgA.source = imageSrc; }
    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(Math.max(64, root.width), Math.max(64, root.height))
        opacity: root.image !== "" && status === Image.Ready && root.flip ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    }
    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(Math.max(64, root.width), Math.max(64, root.height))
        opacity: root.image !== "" && status === Image.Ready && !root.flip ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
    }
}
