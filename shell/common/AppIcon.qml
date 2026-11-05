import QtQuick
import QtQuick.Effects
import "../theme"

// Icon app thống nhất cho dock, lưới Ứng dụng, menu dock, Quản lý tác vụ.
//   name   : icon Islet riêng (shell/assets/apps[-min]/<name>.svg) — vd. "files", "terminal"
//   source : icon thật của app (đường dẫn) — dùng khi app chưa có icon Islet
// Kiểu Tối giản: app lạ được đặt lên ô than giống icon Islet, màu dịu đi (~30%) cho đồng bộ.
// Kiểu Sắc màu: hiện nguyên icon thật.
Item {
    id: root
    property string name: ""
    property string source: ""
    property real size: 48
    implicitWidth: size
    implicitHeight: size

    readonly property bool minimal: Prefs.iconStyle !== "color"
    readonly property bool own: name !== ""

    // SVG của Islet chừa lề 6/128 cho bóng → vẽ to hơn một chút để squircle đúng bằng size
    Image {
        anchors.centerIn: parent
        visible: root.own || root.minimal
        width: root.size * 128 / 116
        height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: root.own ? Theme.appIcon(root.name) : root.minimal ? Theme.appIcon("_tile") : ""
        smooth: true
        mipmap: true
    }

    Image {
        id: real
        anchors.centerIn: parent
        visible: !root.own && !root.minimal
        width: root.minimal ? root.size * 0.6 : root.size
        height: width
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        source: root.own ? "" : root.source
        smooth: true
        mipmap: true
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: real
        source: real
        visible: !root.own && root.minimal
        saturation: -0.7
        brightness: 0.04
    }
}
