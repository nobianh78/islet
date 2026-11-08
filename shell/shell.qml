//@ pragma IconTheme Islet
import QtQuick
import Quickshell
import Quickshell.Io
import "island"
import "wallpaper"
import "bar"
import "dock"
import "controlcenter"
import "widgets"
import "launcher"
import "power"
import "taskmanager"
import "installer"
import "store"
import "lock"
import "notifications"
import "settings"
import "trash"
import "backups"
import "desktop"
import "welcome"
import "snap"
import "search"
import "overview"
import "services"
import "theme"

// Islet shell. Chạy bằng: qs -p shell
ShellRoot {
    id: root

    // Bản cài từ gói (/usr/share/islet/shell): KHÔNG tự nạp lại khi file đổi — pacman thay file từng cái,
    // nạp giữa chừng sẽ lỗi. Hook của islet-shell gọi `qs ipc call shell reload` khi đã cài xong.
    // Đang khoá màn hình thì đợi mở khoá rồi mới nạp (nạp lại lúc khoá làm màn hình khoá chết).
    // Bản đang phát triển (~/.config/islet/shell) vẫn tự nạp như thường.
    Component.onCompleted: {
        if (Quickshell.shellDir.startsWith("/usr/")) Quickshell.watchFiles = false;
        Sounds.startupOnce();          // tiếng bật máy (một lần mỗi phiên)
    }
    property bool reloadPending: false
    function reloadShell() { if (Ui.locked) reloadPending = true; else Quickshell.reload(false); }
    Connections {
        target: Ui
        function onLockedChanged() { if (!Ui.locked && root.reloadPending) { root.reloadPending = false; reloadLater.restart(); } }
    }
    Timer { id: reloadLater; interval: 2000; onTriggered: Quickshell.reload(false) }
    // máy mới cài: hiện màn hình Chào mừng một lần (đợi shell dựng xong và đã mở khoá)
    Timer {
        interval: 2500
        running: Prefs.loaded && !Prefs.welcomeDone && !Ui.locked && !Ui.liveSession
        onTriggered: if (!Prefs.welcomeDone) Ui.welcomeOpen = true
    }
    IpcHandler {
        target: "shell"
        function reload(): void { root.reloadShell(); }
    }
    // Màn hình khoá dựng TRƯỚC và ngay (lúc bật máy nó nối tiếp màn hình khởi động, nên phải hiện
    // càng sớm càng tốt). Mọi thứ khác nạp ngầm (activeAsync) để không làm chậm khung đầu tiên.
    LockScreen {}

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Wallpaper { screen: perScreen.modelData }
            DimOverlay { screen: perScreen.modelData }
            LazyLoader { activeAsync: true; Bar { screen: perScreen.modelData } }
            LazyLoader { activeAsync: true; Dock { screen: perScreen.modelData } }
            LazyLoader { activeAsync: true; FocusFrame { screen: perScreen.modelData } }
            LazyLoader { activeAsync: true; WindowTabs { screen: perScreen.modelData } }
        }
    }

    // widget + ghi chú dán: chỉ ở màn hình chính
    LazyLoader { activeAsync: true; Desktop { screen: Quickshell.screens[0] ?? null } }
    LazyLoader { id: islandL; activeAsync: true; Island {} }
    readonly property var island: islandL.item
    LazyLoader { activeAsync: true; ControlCenter {} }
    LazyLoader { activeAsync: true; Launcher {} }
    LazyLoader { activeAsync: true; PowerMenu {} }
    LazyLoader { activeAsync: true; TaskManager {} }
    LazyLoader { activeAsync: true; Installer {} }
    LazyLoader { activeAsync: true; Store {} }
    LazyLoader { activeAsync: true; Settings {} }
    LazyLoader { activeAsync: true; TrashWindow {} }
    LazyLoader { activeAsync: true; BackupsWindow {} }
    LazyLoader { activeAsync: true; Welcome {} }
    LazyLoader { activeAsync: true; WidgetGallery {} }
    LazyLoader { activeAsync: true; NotifCenter {} }
    LazyLoader { activeAsync: true; Snap {} }
    LazyLoader { activeAsync: true; Search {} }
    LazyLoader { activeAsync: true; Overview {} }

    // áp màu nhấn / màn hình đã lưu vào Hyprland ngay khi shell chạy
    readonly property string hyprSync: HyprSync.file
    // giữ thư mục "This PC" của Files cập nhật (dung lượng ổ, USB)
    readonly property var thisPc: ThisPC
    // chờ máy (tối / khoá / tắt màn hình / ngủ) + Night Light
    readonly property var idle: Idle
    readonly property var nightLight: NightLight
    readonly property var desktopSync: DesktopSync
    readonly property var busyCursor: BusyCursor
    readonly property var ime: Ime
    // Time Machine: theo dõi ổ sao lưu, tự sao lưu khi cắm vào
    readonly property var backup: Backup

    // Điều khiển từ terminal hoặc phím tắt:
    //   qs -p shell ipc call island toggle
    //   qs -p shell ipc call island test notif|volume|battery
    //   qs -p shell ipc call cc toggle
    IpcHandler {
        target: "island"
        function toggle(): void { if (island) island.expanded = !island.expanded; }
        function test(kind: string): void { if (island) island.flash(kind, 3000); }
        function open(tab: string): void { if (island) island.expand(tab); }
    }
    IpcHandler {
        target: "win"
        function minimize(): void { Windows.minimize(); }
        function maximize(): void { Windows.toggleMaximize(); }
        function close(): void { Windows.close(); }
    }
    IpcHandler {
        target: "ui"
        function frame(on: bool): void { Ui.frameHint = on; }
    }
    IpcHandler {
        target: "store"
        function open(): void { Ui.openStore(); }
        function toggle(): void { if (Ui.storeOpen && Windows.storeActive) Ui.storeOpen = false; else Ui.openStore(); }
    }
    // chẩn đoán: qs ipc call media state → island đang hiện bài nào, vì sao
    IpcHandler {
        target: "media"
        function state(): string {
            return JSON.stringify({ raw: Media.rawTitle, title: Media.title, artist: Media.artist, preview: Media.preview,
                tabs: Media.ytTabs, good: Media.goodTitle, url: Media.url, pos: Media.position, len: Media.length,
                player: Media.busName, lyrics: Lyrics.status, line: Lyrics.current });
        }
    }
    IpcHandler {
        target: "trash"
        function open(): void { Ui.openTrash(); }
        function empty(): void { Trash.empty(); }
    }
    IpcHandler {
        target: "welcome"
        function open(): void { Ui.welcomeOpen = true; }
    }
    IpcHandler {
        target: "desktop"
        function note(): void { DesktopItems.focusNote(DesktopItems.addNote()); }
        function widgets(on: bool): void { Prefs.set("desktopWidgets", on); }
        function gallery(): void { Ui.openWidgets(); }
        function add(kind: string): void { DesktopItems.addWidget(kind); }
        function stacks(on: bool): void { DesktopItems.setStacks(on); }
    }
    IpcHandler {
        target: "backup"
        function open(): void { Ui.openBackups(); }
        function now(): void { Backup.backup(); }
    }
    IpcHandler {
        target: "installer"
        function open(): void { Ui.installerOpen = true; }
    }
    IpcHandler {
        target: "taskmgr"
        function toggle(): void { Ui.toggleTask(); }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { Ui.togglePower(); }
        function lid(closed: bool): void { Idle.lid(closed); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { Ui.toggleLauncher(); }
    }
    IpcHandler {
        target: "recorder"
        function toggle(): void { if (Recorder.recording) Recorder.stop(); else Recorder.start(true); }
        function full(): void { if (!Recorder.recording) Recorder.start(false); }
    }
    IpcHandler {
        target: "search"
        function toggle(): void { Ui.toggleSearch(); }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { Ui.lock(); }
    }
    IpcHandler {
        target: "settings"
        function open(): void { Ui.openSettings(""); }
        function page(id: string): void { Ui.openSettings(id); }
        function toggle(): void { if (Ui.settingsOpen && Windows.settingsActive) Ui.settingsOpen = false; else Ui.openSettings(""); }
    }
    IpcHandler {
        target: "notifs"
        function toggle(): void { Ui.toggleNotifs(); }
        function clear(): void { Notifs.clearAll(); }
    }
    IpcHandler {
        target: "cc"
        function toggle(): void { Ui.toggleControlCenter(); }
    }
}
