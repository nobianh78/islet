pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../theme"

// Chờ máy: tối màn hình → khoá → tắt màn hình → ngủ (thời gian chỉnh ở Cài đặt › Power).
// App đang phát video / gọi điện giữ "idle inhibitor" thì không làm gì (respectInhibitors).
// Gập laptop (Hyprland báo qua `islet-ipc power lid`): khoá trước rồi mới ngủ.
// Pin ≤ 20% và chưa cắm sạc → tự bật Tiết kiệm pin (nếu được bật), cắm sạc thì trả về chế độ cũ.
Singleton {
    id: root

    readonly property bool onBattery: UPower.onBattery
    readonly property int sleepAfter: onBattery ? Prefs.sleepAfterBattery : Prefs.sleepAfterAC
    property bool dimmed: false
    property bool screenOff: false

    function sleepNow() {
        Ui.lock();
        later.restart();
    }
    Timer { id: later; interval: 900; onTriggered: Quickshell.execDetached(["systemctl", "suspend"]) }
    function lid(closed) {
        if (!closed) { setScreen(true); return; }
        if (Prefs.lidAction === "sleep") sleepNow();
        else if (Prefs.lidAction === "lock") { Ui.lock(); setScreen(false); }
    }
    function setScreen(on) {
        if (screenOff === !on) return;
        screenOff = !on;
        Hyprland.dispatch('hl.dsp.dpms({ action = "' + (on ? "on" : "off") + '" })');
    }

    // Một IdleMonitor duy nhất (rảnh sau 5 giây, tôn trọng inhibitor của video / cuộc gọi); các nấc
    // tối → khoá → tắt màn hình → ngủ tự đếm từ lúc bắt đầu rảnh. (Nhiều IdleMonitor cùng lúc chỉ có
    // cái tạo sau cùng hoạt động.)
    readonly property int grace: 5
    property real idleSince: 0          // 0 = đang dùng máy
    property int stage: 0               // 0 dùng · 1 tối · 2 khoá · 3 tắt màn hình · 4 ngủ
    IdleMonitor {
        timeout: root.grace
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) { root.idleSince = Date.now() - root.grace * 1000; root.stage = 0; tick.restart(); }
            else { root.idleSince = 0; root.stage = 0; tick.stop(); root.dimmed = false; root.setScreen(true); }
        }
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            if (!root.idleSince) { stop(); return; }
            const s = (Date.now() - root.idleSince) / 1000;
            const due = (t) => t > 0 && s >= t;
            if (root.stage < 4 && due(root.sleepAfter)) { root.stage = 4; root.dimmed = false; root.sleepNow(); stop(); return; }
            if (root.stage < 3 && due(Prefs.screenOffAfter)) { root.stage = 3; root.dimmed = false; root.setScreen(false); }
            if (root.stage < 2 && due(Prefs.lockAfter)) { root.stage = 2; root.dimmed = false; if (!Ui.locked) Ui.lock(); }
            if (root.stage < 1 && due(Prefs.dimAfter)) { root.stage = 1; root.dimmed = !Ui.locked; }
        }
    }

    // ---- tự Tiết kiệm pin ----
    property int savedProfile: -1
    readonly property real percent: UPower.displayDevice?.percentage ?? 1
    onPercentChanged: autoSave()
    onOnBatteryChanged: autoSave()
    function autoSave() {
        if (!Prefs.autoSaver) return;
        const low = onBattery && percent <= 0.2;
        if (low && PowerProfiles.profile !== PowerProfile.PowerSaver) {
            savedProfile = PowerProfiles.profile;
            PowerProfiles.profile = PowerProfile.PowerSaver;
            Ui.toast("Battery saver on · " + Math.round(percent * 100) + "% left", "", "");
        } else if (!onBattery && savedProfile >= 0) {
            PowerProfiles.profile = savedProfile;
            savedProfile = -1;
        }
    }
}
