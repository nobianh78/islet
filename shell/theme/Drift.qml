pragma Singleton
import QtQuick
import Quickshell

// Đồng hồ chung cho chuyển động trôi của hình nền: mọi Backdrop (màn hình nền, màn hình khoá,
// ô xem trước) tính vị trí đốm màu theo cùng một thời điểm → mở khoá xong hình nền khớp liền,
// không bị "nhảy".
Singleton {
    readonly property real start: Date.now()
    property real t: 0          // giây
    // Chỉ trôi khi có người ngắm: màn hình nền trống hoặc đang khoá (Wallpaper.qml đặt cờ này).
    // Có cửa sổ / panel kính đè lên thì đứng yên — trôi lúc đó chỉ bắt Hyprland làm mờ lại kính liên tục.
    property bool active: true
    Timer {
        interval: 100              // chuyển động rất chậm (vài px / giây) → 10 lần/giây là đủ mượt, đỡ tốn CPU
        running: parent.active
        repeat: true
        onTriggered: parent.t = (Date.now() - parent.start) / 1000
    }
}
