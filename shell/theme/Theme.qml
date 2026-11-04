pragma Singleton
import QtQuick
import Quickshell

// Bảng màu, font và thông số chuyển động dùng chung cho toàn bộ Islet shell.
// Màu lấy từ logo Islet (branding/islet-mark-dark-bg.svg).
Singleton {
    // --- Màu thương hiệu ---
    readonly property color violet: "#8B7CFF"
    readonly property color pink: "#FF6B97"
    readonly property color teal: "#5EEAD4"
    readonly property color amber: "#FFB547"
    readonly property color green: "#4ADE80"
    readonly property color red: "#FF6A6A"

    // --- Nền ---
    readonly property color ink: "#07070F"        // mặt nạ mèo = thân island
    readonly property color base: "#0A0A14"
    readonly property color text: "#FFFFFF"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.68)
    readonly property color textFaint: Qt.rgba(1, 1, 1, 0.42)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.08)
    readonly property color track: Qt.rgba(1, 1, 1, 0.22)

    // --- Font ---
    readonly property string font: "Be Vietnam Pro"
    readonly property string mono: "JetBrains Mono"

    // --- Chuyển động ---
    // Lò xo cho khung island: hơi nảy, dừng nhanh.
    readonly property real springW: 3.6
    readonly property real dampW: 0.26
    readonly property real springH: 3.2
    readonly property real dampH: 0.30
    readonly property real mass: 1.0

    // Thời gian mờ dần nội dung khi đổi chế độ.
    readonly property int fadeIn: 260
    readonly property int fadeOut: 140
    readonly property int fadeDelay: 90
}
