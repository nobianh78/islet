pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

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
    // Không làm phiền theo giờ (Cài đặt › Notifications)
    property real clockNow: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.clockNow = Date.now() }
    // Chế độ Tập trung: không banner, ẩn widget/file màn hình nền, tối hình nền và cửa sổ không đang dùng
    property bool focusMode: false
    // Hồ sơ: hình nền riêng (""= giữ nguyên), độ tối hình nền, dock tự ẩn
    readonly property var focusProfiles: ({
        work:  { label: "Work",  wall: "",                                       dim: 0.6, dockHide: true },
        sleep: { label: "Sleep", wall: "/usr/share/islet/wallpapers/midnight.jpg", dim: 0.75, dockHide: true }
    })
    readonly property var focusProfile: focusProfiles[Prefs.focusKind] ?? focusProfiles.work
    onFocusModeChanged: {
        Prefs.focusWall = focusMode ? focusProfile.wall : "";
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { dim_inactive = ${focusMode}, dim_strength = 0.55 } })`]);
    }
    readonly property bool dndNow: {
        if (focusMode) return true;
        if (!Prefs.dndScheduled) return false;
        const d = new Date(clockNow), m = d.getHours() * 60 + d.getMinutes();
        const t = x => { const p = x.split(":"); return +p[0] * 60 + +p[1]; };
        const a = t(Prefs.dndFrom), b = t(Prefs.dndTo);
        return a <= b ? (m >= a && m < b) : (m >= a || m < b);
    }
    signal islandOpenRequested(string tab)
    function openIsland(tab) { closeAll(); islandOpenRequested(tab); }
    function toggleSearch() { const o = !searchOpen; closeAll(); searchOpen = o; }
    property bool locked: false          // màn hình khoá
    // Shell được Hyprland mở lúc vừa đăng nhập (ISLET_BOOT=1): màn hình khoá nối tiếp màn hình khởi động
    readonly property bool fromBoot: Quickshell.env("ISLET_BOOT") === "1"
    property bool bootIntro: false       // lần khoá đầu tiên là "từ boot" (con mèo bay từ giữa màn hình xuống)

    function lock() { closeAll(); locked = true; }
    // Cài đặt là cửa sổ thật: mở lại khi đang mở = đưa nó lên (kể cả đang thu nhỏ)
    signal settingsRaiseRequested()
    // Cửa hàng cũng là cửa sổ thật
    signal storeRaiseRequested()
    // Thùng rác
    property bool trashOpen: false
    signal trashRaiseRequested()
    function openTrash() { launcherOpen = false; if (trashOpen) trashRaiseRequested(); trashOpen = true; }
    signal trashEmptyAsked()           // menu dock › Empty Trash: mở cửa sổ và hỏi xác nhận
    function askEmptyTrash() { openTrash(); trashEmptyAsked(); }
    // Chào mừng (chạy một lần sau khi cài; không hiện trên bản chạy thử từ USB/ISO)
    property bool welcomeOpen: false
    property bool liveSession: false
    Process { running: true; command: ["test", "-d", "/run/archiso"]; onExited: code => root.liveSession = code === 0 }
    // Kho widget của màn hình nền
    property bool widgetsOpen: false
    signal widgetsRaiseRequested()
    function openWidgets() { launcherOpen = false; if (widgetsOpen) widgetsRaiseRequested(); widgetsOpen = true; }
    // Time Machine: xem lại / khôi phục file từ các bản sao lưu
    property bool backupsOpen: false
    signal backupsRaiseRequested()
    function openBackups() { launcherOpen = false; if (backupsOpen) backupsRaiseRequested(); backupsOpen = true; }
    function openStore() { launcherOpen = false; if (storeOpen) storeRaiseRequested(); storeOpen = true; }
    function openSettings(page) { closeAll(); if (page) settingsPage = page; if (settingsOpen) settingsRaiseRequested(); settingsOpen = true; }
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
        if (id === "islet-store") { openStore(); return; }
        if (id === "islet-installer") { installerOpen = true; launcherOpen = false; return; }
        if (id === "islet-settings") { openSettings(""); return; }
        if (e) appStarting();
        e?.execute();
    }
    function toggleControlCenter() { controlCenterOpen = !controlCenterOpen; if (controlCenterOpen) notifOpen = false; }

    // Kéo thả app từ Launcher vào Dock để ghim
    property bool dockDropHover: false

    // Dock báo cho island biết đang mở app nào.
    property string launchLabel: ""
    property string launchIcon: ""
    property color launchTile: "#8B7CFF"
    property string launchIconUrl: ""   // icon app bất kỳ (đường dẫn), dùng thay launchIcon
    signal launching()
    signal appStarting()      // một app ngoài vừa được mở → con trỏ "đang mở" (BusyCursor)

    function announceLaunch(label, icon, tile) {
        launchLabel = label;
        launchIcon = icon;
        launchTile = tile;
        launchIconUrl = "";
        launching();
        appStarting();
    }

    // key: icon Islet riêng nếu app có (Theme.appKey), không thì dùng url icon thật
    function announceLaunchUrl(label, url, key) {
        launchLabel = label;
        launchIcon = key || "";
        launchIconUrl = key ? "" : url;
        launching();
        appStarting();
    }
}
