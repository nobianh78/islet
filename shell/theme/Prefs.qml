pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cài đặt của người dùng (app Cài đặt ghi vào đây), lưu ở ~/.config/islet/settings.json.
//   accent     màu nhấn toàn hệ thống
//   wallpaper  "preset:<id>" (hình nền động) hoặc đường dẫn ảnh
//   dnd        Không làm phiền: không bật thông báo lên island
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/islet"

    // ---- bảng chọn ----
    readonly property var accents: [
        { id: "violet", label: "Islet Violet", color: "#8B7CFF" },
        { id: "blue",   label: "Blue", color: "#5B8CFF" },
        { id: "teal",   label: "Teal",      color: "#2EC4B6" },
        { id: "green",  label: "Leaf",        color: "#34C77B" },
        { id: "amber",  label: "Orange",       color: "#FF9F43" },
        { id: "pink",   label: "Pink",      color: "#FF6B97" },
        { id: "red",    label: "Red",        color: "#FF5F57" }
    ]
    // Hình nền động: ba đốm màu nhoè [màu, độ đậm] + màu nền
    readonly property var presets: [
        { id: "islet",  label: "Islet",      base: "#0A0A14", blobs: [["#5B4BFF", 0.75], ["#FF4F8B", 0.55], ["#14B8A6", 0.50]] },
        { id: "dawn",   label: "Dawn",  base: "#140A0C", blobs: [["#FF7A45", 0.70], ["#FF4F8B", 0.55], ["#FFC24B", 0.45]] },
        { id: "ocean",  label: "Ocean",  base: "#050B16", blobs: [["#2563EB", 0.75], ["#06B6D4", 0.55], ["#6D4AFF", 0.45]] },
        { id: "forest", label: "Forest",       base: "#06100C", blobs: [["#10B981", 0.65], ["#84CC16", 0.40], ["#0EA5B7", 0.50]] },
        { id: "aurora", label: "Aurora",  base: "#070A12", blobs: [["#22D3EE", 0.60], ["#A855F7", 0.60], ["#4ADE80", 0.40]] },
        { id: "night",  label: "Night",        base: "#050509", blobs: [["#312E81", 0.80], ["#581C87", 0.55], ["#1E293B", 0.60]] }
    ]

    // ---- giá trị ----
    property string accentId: "violet"
    property string wallpaper: "preset:islet"
    property bool dnd: false
    property string iconStyle: "minimal"   // "minimal" (Tối giản) | "color" (Sắc màu)
    property bool lockOnBoot: true         // bật máy xong vào màn hình khoá (nối tiếp màn hình khởi động)
    property var monitors: ({})        // tên màn hình → { mode: "1920x1080@60", scale: 1.25 }

    // ---- nguồn điện & chờ máy (giây; 0 = không bao giờ) ----
    property int dimAfter: 120
    property int lockAfter: 300
    property int screenOffAfter: 360
    property int sleepAfterBattery: 900
    property int sleepAfterAC: 0
    property string lidAction: "sleep"      // sleep | lock | nothing
    property bool autoSaver: true           // pin ≤ 20% → tự chuyển Tiết kiệm pin
    // ---- Night Light ----
    property string nightMode: "off"        // off | schedule | on
    property string nightFrom: "19:00"
    property string nightTo: "06:30"
    property int nightTemp: 4200
    // ---- chuột & touchpad ----
    property bool naturalScroll: true
    property bool tapToClick: true
    property bool disableWhileTyping: true
    property real pointerSpeed: 0           // -1 … 1
    property real scrollSpeed: 1

    readonly property color accent: (accents.find(a => a.id === accentId) ?? accents[0]).color
    readonly property bool wallpaperIsImage: !wallpaper.startsWith("preset:")
    readonly property var preset: presets.find(p => "preset:" + p.id === wallpaper) ?? presets[0]

    readonly property var simpleKeys: ["dimAfter", "lockAfter", "screenOffAfter", "sleepAfterBattery", "sleepAfterAC", "lidAction", "autoSaver",
        "nightMode", "nightFrom", "nightTo", "nightTemp", "naturalScroll", "tapToClick", "disableWhileTyping", "pointerSpeed", "scrollSpeed"]

    function set(key, value) {
        root[key] = value;
        save.restart();
    }

    property bool loaded: false
    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: file.reload()
    }
    FileView {
        id: file
        path: root.dir + "/settings.json"
        blockLoading: true          // đọc ngay lúc khởi động, để biết có khoá lúc bật máy hay không
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text() || "{}");
                if (typeof d.accent === "string") root.accentId = d.accent;
                if (typeof d.wallpaper === "string") root.wallpaper = d.wallpaper;
                if (typeof d.dnd === "boolean") root.dnd = d.dnd;
                if (typeof d.iconStyle === "string") root.iconStyle = d.iconStyle;
                if (typeof d.lockOnBoot === "boolean") root.lockOnBoot = d.lockOnBoot;
                if (d.monitors && typeof d.monitors === "object") root.monitors = d.monitors;
                for (const k of root.simpleKeys) if (d[k] !== undefined && typeof d[k] === typeof root[k]) root[k] = d[k];
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    Timer {
        id: save
        interval: 250
        onTriggered: {
            const d = { accent: root.accentId, wallpaper: root.wallpaper, dnd: root.dnd, iconStyle: root.iconStyle, lockOnBoot: root.lockOnBoot, monitors: root.monitors };
            for (const k of root.simpleKeys) d[k] = root[k];
            file.setText(JSON.stringify(d, null, 1));
        }
    }
}
