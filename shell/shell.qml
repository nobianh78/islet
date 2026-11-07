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
import "snap"
import "search"
import "overview"
import "services"
import "theme"

// Islet shell. Chạy bằng: qs -p shell
ShellRoot {
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

    LazyLoader { id: islandL; activeAsync: true; Island {} }
    readonly property var island: islandL.item
    LazyLoader { activeAsync: true; ControlCenter {} }
    LazyLoader { activeAsync: true; Launcher {} }
    LazyLoader { activeAsync: true; PowerMenu {} }
    LazyLoader { activeAsync: true; TaskManager {} }
    LazyLoader { activeAsync: true; Installer {} }
    LazyLoader { activeAsync: true; Store {} }
    LazyLoader { activeAsync: true; Settings {} }
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
    readonly property var ime: Ime

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
        function open(): void { Ui.storeOpen = true; }
        function toggle(): void { Ui.storeOpen = !Ui.storeOpen; }
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
        function toggle(): void { if (Ui.settingsOpen) Ui.settingsOpen = false; else Ui.openSettings(""); }
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
