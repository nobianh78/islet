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

    // --- Chủ đề Tối / Sáng ---
    // Giai đoạn 1: cửa sổ và bảng (Cài đặt, Cửa hàng, Thùng rác, trung tâm điều khiển…) theo chủ đề.
    // Island, dock, thanh trên, màn hình khoá giữ nguyên tối. Chế độ tối trả về đúng các giá trị cũ.
    property real tick: Date.now()
    Timer { interval: 60000; running: Prefs.themeMode === "auto"; repeat: true; onTriggered: Theme.tick = Date.now() }
    // shortcut: giờ sáng cố định 6:30–18:30, không theo giờ mặt trời; thêm khi cần = đọc từ Prefs
    readonly property bool isDay: { const d = new Date(tick), m = d.getHours() * 60 + d.getMinutes(); return m >= 390 && m < 1110; }
    readonly property bool light: Prefs.themeMode === "light" || (Prefs.themeMode === "auto" && isDay)

    readonly property color label: light ? "#1C1C1E" : "#FFFFFF"        // chữ chính
    readonly property color labelSoft: light ? "#3A3A3C" : "#D1D1D6"
    readonly property color subtle: light ? "#505054" : "#AEAEB2"
    readonly property color muted: light ? "#6C6C70" : "#8E8E93"       // chữ phụ
    readonly property color faint: light ? "#8E8E93" : "#636366"
    readonly property color window: light ? "#F2F2F7" : "#0D0D15"      // nền cửa sổ
    function fg(a) { return light ? Qt.rgba(0, 0, 0, a) : Qt.rgba(1, 1, 1, a); }          // lớp phủ nhẹ (hover, thẻ, đường kẻ)
    function surface(a) { return light ? Qt.rgba(1, 1, 1, Math.min(0.97, a + 0.4)) : Qt.rgba(0.07, 0.07, 0.11, a < 0.9 ? a * (1 - 0.6 * Prefs.glass) : a); }   // kính / bảng nổi

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
