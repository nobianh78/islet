pragma Singleton
import QtQuick
import Quickshell

// Trạng thái giao diện dùng chung giữa các cửa sổ (thanh trên, dock, island, trung tâm điều khiển).
Singleton {
    id: root

    property bool controlCenterOpen: false
    property bool launcherOpen: false    // trình xem tất cả app
    property bool powerOpen: false       // menu nguồn (bấm logo mèo)
    property bool taskOpen: false        // Quản lý tác vụ
    property bool installerOpen: false   // trình cài Islet vào ổ cứng
    property bool storeOpen: false       // Cửa hàng ứng dụng
    property bool settingsOpen: false    // app Cài đặt
    property string settingsPage: "wallpaper"
    property bool notifOpen: false       // trung tâm thông báo
    property bool searchOpen: false      // Islet Search (Super+Space)
    signal islandOpenRequested(string tab)
    function openIsland(tab) { closeAll(); islandOpenRequested(tab); }
    function toggleSearch() { const o = !searchOpen; closeAll(); searchOpen = o; }
    property bool locked: false          // màn hình khoá
    // Shell được Hyprland mở lúc vừa đăng nhập (ISLET_BOOT=1): màn hình khoá nối tiếp màn hình khởi động
    readonly property bool fromBoot: Quickshell.env("ISLET_BOOT") === "1"
    property bool bootIntro: false       // lần khoá đầu tiên là "từ boot" (con mèo bay từ giữa màn hình xuống)

    function lock() { closeAll(); locked = true; }
    function openSettings(page) { closeAll(); if (page) settingsPage = page; settingsOpen = true; }
    function toggleNotifs() { const o = !notifOpen; closeAll(); notifOpen = o; }
    function closeAll() { controlCenterOpen = false; launcherOpen = false; powerOpen = false; notifOpen = false; }

    // toast trên island: toast("Đã cài VLC ✓", iconUrl hoặc "", "store" | "error")
    signal toastRequested(string text, string icon, string kind)
    function toast(text, icon, kind) { toastRequested(text, icon, kind); }
    function toggleTask() { taskOpen = !taskOpen; if (taskOpen) { powerOpen = false; controlCenterOpen = false; launcherOpen = false; } }
    function togglePower() { powerOpen = !powerOpen; if (powerOpen) controlCenterOpen = false; }
    function toggleLauncher() { launcherOpen = !launcherOpen; if (launcherOpen) controlCenterOpen = false; }
    property bool activeHasTab: false    // cửa sổ đang chọn có tab ba chấm riêng (nếu không, thanh trên hiện ba chấm)
    // Đang rê vào ba chấm / tên app trên thanh trên → viền sáng cửa sổ đang chọn.
    // Tự tắt sau 4 giây phòng khi sự kiện "rời chuột" bị lỡ.
    property bool frameHint: false
    onFrameHintChanged: if (frameHint) frameGuard.restart()
    Timer { id: frameGuard; interval: 4000; onTriggered: root.frameHint = false }
    // App nội bộ của Islet: mở thẳng trong shell, không qua lệnh ngoài
    function launchEntry(e) {
        const id = e?.id ?? "";
        if (id === "islet-store") { storeOpen = true; launcherOpen = false; return; }
        if (id === "islet-installer") { installerOpen = true; launcherOpen = false; return; }
        if (id === "islet-settings") { openSettings(""); return; }
        e?.execute();
    }
    function toggleControlCenter() { controlCenterOpen = !controlCenterOpen; if (controlCenterOpen) notifOpen = false; }

    // Dock báo cho island biết đang mở app nào.
    property string launchLabel: ""
    property string launchIcon: ""
    property color launchTile: "#8B7CFF"
    property string launchIconUrl: ""   // icon app bất kỳ (đường dẫn), dùng thay launchIcon
    signal launching()

    function announceLaunch(label, icon, tile) {
        launchLabel = label;
        launchIcon = icon;
        launchTile = tile;
        launchIconUrl = "";
        launching();
    }

    // key: icon Islet riêng nếu app có (Theme.appKey), không thì dùng url icon thật
    function announceLaunchUrl(label, url, key) {
        launchLabel = label;
        launchIcon = key || "";
        launchIconUrl = key ? "" : url;
        launching();
    }
}
