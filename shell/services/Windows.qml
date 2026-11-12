pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Điều khiển cửa sổ: đóng, thu nhỏ, phóng to.
// Hyprland không có "thu nhỏ", nên Islet cất cửa sổ vào workspace ẩn "special:minimized";
// bấm icon app trên dock để lấy lại.
Singleton {
    id: root

    readonly property string minimizedWs: "special:minimized"

    readonly property var active: Hyprland.activeToplevel
    readonly property bool hasActive: active !== null && (active.workspace?.name ?? "") !== minimizedWs
    readonly property bool activeMaximized: (active?.lastIpcObject?.fullscreen ?? 0) === 1

    signal minimizedApp(string appId)

    // cửa sổ riêng của Islet (Quickshell FloatingWindow: Settings, Store) — tìm theo tiêu đề
    function isShell(t, title) { return appIdOf(t) === "org.quickshell" && ((t?.title || t?.lastIpcObject?.title) ?? "") === title; }
    function shellWin(title) { return Hyprland.toplevels.values.find(t => isShell(t, title)) ?? null; }
    function shellActive(title) { return hasActive && isShell(active, title); }
    function shellMinimized(title) { return Hyprland.toplevels.values.some(t => isShell(t, title) && isMinimized(t)); }
    // đưa cửa sổ lên (lấy lại nếu đang thu nhỏ) · thu nhỏ
    function raiseShell(title) {
        Hyprland.refreshToplevels();
        const t = shellWin(title);
        if (!t) return;
        if (isMinimized(t)) restore(t); else focusWin(t);
    }
    function minimizeShell(title) {
        Hyprland.refreshToplevels();
        const t = shellWin(title);
        if (t) minimizeWin(t);
        return t !== null;
    }
    readonly property bool settingsActive: shellActive("Settings")
    readonly property bool settingsMinimized: shellMinimized("Settings")
    readonly property bool storeActive: shellActive("Store")
    readonly property bool storeMinimized: shellMinimized("Store")

    readonly property int openCount: Hyprland.toplevels.values.length

    function addr(t) {
        const a = String(t.address ?? "");
        return "address:" + (a.startsWith("0x") ? a : "0x" + a);
    }
    function appIdOf(t) {
        return t?.wayland?.appId ?? t?.lastIpcObject?.class ?? "";
    }
    function isMinimized(t) {
        return (t?.workspace?.name ?? "") === minimizedWs;
    }

    function close() {
        if (hasActive) Hyprland.dispatch("hl.dsp.window.close()");
    }
    function toggleMaximize() {
        if (!hasActive) return;
        Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized" })');
        refresh.restart();
    }
    function minimize() {
        if (!hasActive) return;
        const id = appIdOf(active);
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + minimizedWs + '", follow = false })');
        minimizedApp(id);
    }

    // ---- Thao tác trên một cửa sổ cụ thể (dùng cho tab trên từng cửa sổ) ----
    readonly property var appNames: ({
        "kitty": "Terminal",
        "firefox": "Firefox",
        "org.gnome.Nautilus": "Files",
        "mpv": "Music"
    })
    function nameOf(t) {
        const id = appIdOf(t);
        return appNames[id] ?? (t?.title || id.replace(/\.exe$/i, "").split(".").pop() || "Apps");
    }
    function focusWin(t) {
        Hyprland.dispatch('hl.dsp.focus({ window = "' + addr(t) + '" })');
        Hyprland.dispatch("hl.dsp.window.bring_to_top()");
    }
    function closeWin(t) { Hyprland.dispatch('hl.dsp.window.close({ window = "' + addr(t) + '" })'); }
    function minimizeWin(t) {
        const id = appIdOf(t);
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + minimizedWs + '", follow = false, window = "' + addr(t) + '" })');
        minimizedApp(id);
    }
    function maximizeWin(t) {
        focusWin(t);
        Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized" })');
        refresh.restart();
    }
    function moveWin(t, x, y) {
        Hyprland.dispatch("hl.dsp.window.move({ x = " + Math.round(x) + ", y = " + Math.round(y) + ', window = "' + addr(t) + '" })');
    }

    // Chuyển sang cửa sổ kế tiếp / trước đó và đưa nó lên trên cùng.
    function cycle(forward) {
        Hyprland.dispatch(forward ? "hl.dsp.window.cycle_next()" : "hl.dsp.window.cycle_next({ prev = true })");
        Hyprland.dispatch("hl.dsp.window.bring_to_top()");
        refresh.restart();
    }

    // Các cửa sổ đang thu nhỏ của một app (theo appId).
    function minimizedOf(ids) {
        const out = [];
        const tl = Hyprland.toplevels.values;
        for (let i = 0; i < tl.length; i++)
            if (isMinimized(tl[i]) && ids.indexOf(appIdOf(tl[i])) >= 0) out.push(tl[i]);
        return out;
    }

    // Đưa cửa sổ về workspace đang xem rồi chọn nó.
    function restore(t) {
        const a = addr(t);
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "e+0", window = "' + a + '" })');
        Hyprland.dispatch('hl.dsp.focus({ window = "' + a + '" })');
    }

    // lastIpcObject chỉ cập nhật khi được yêu cầu.
    Timer { id: refresh; interval: 120; onTriggered: Hyprland.refreshToplevels() }
}
