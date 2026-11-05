pragma Singleton
import QtQuick
import Quickshell

// Bảng màu, font và thông số chuyển động dùng chung cho toàn bộ Islet shell.
// Màu lấy từ logo Islet (branding/islet-mark-dark-bg.svg).
Singleton {
    // --- Màu thương hiệu ---
    // Màu nhấn: đổi trong app Cài đặt (Prefs.accent). Tên "violet" giữ lại cho gọn.
    readonly property color violet: Prefs.accent
    readonly property color accent: Prefs.accent
    // Icon app của Islet theo kiểu đang chọn: Tối giản (theo màu nhấn) hoặc Sắc màu
    function appIcon(name) {
        if (!name) return "";
        return Prefs.iconStyle === "color" ? Qt.resolvedUrl("../assets/apps/" + name + ".svg")
            : Qt.resolvedUrl("../assets/apps-min/" + Prefs.accentId + "/" + name + ".svg");
    }
    // id .desktop / tên icon → icon Islet riêng (theo màu nhấn); "" nếu chưa có
    readonly property var appKeys: ({
        "org.gnome.Nautilus": "files", "nautilus": "files", "system-file-manager": "files",
        "firefox": "browser", "kitty": "terminal", "code-oss": "code", "com.visualstudio.code.oss": "code",
        "mpv": "video", "islet-store": "store", "islet-settings": "settings", "org.gnome.Settings": "settings",
        "islet-installer": "islet", "islet": "islet"
    })
    function appKey(id) { return appKeys[id] ?? appKeys[(id || "").toLowerCase()] ?? ""; }
    function tint(a) { return Qt.rgba(violet.r, violet.g, violet.b, a); }
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
