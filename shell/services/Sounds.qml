pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Âm thanh hệ thống của Islet (theme âm thanh "islet" — tạo bằng scripts/make-sounds.py; thiếu file thì
// lấy bộ freedesktop): bật máy · thông báo · khoá / mở khoá · cắm / rút sạc · xong việc · hết giờ ·
// lỗi · bỏ vào / đổ thùng rác · chụp màn hình.
// Tắt hết trong Cài đặt › Sound (Prefs.systemSounds); tiếng thông báo riêng: Prefs.notifSounds.
Singleton {
    id: root
    readonly property string dir: "/usr/share/sounds/islet/stereo/"
    readonly property string fallback: "/usr/share/sounds/freedesktop/stereo/"
    // sự kiện → [tên trong theme Islet, tên trong bộ freedesktop]
    readonly property var files: ({
        startup: ["desktop-login.wav", "service-login.oga"],
        notification: ["message-new-instant.wav", "message-new-instant.oga"],
        lock: ["service-logout.wav", "device-removed.oga"],
        unlock: ["service-login.wav", "service-login.oga"],
        plug: ["power-plug.wav", "power-plug.oga"],
        unplug: ["power-unplug.wav", "power-unplug.oga"],
        done: ["complete.wav", "complete.oga"],
        alarm: ["alarm-clock-elapsed.wav", "alarm-clock-elapsed.oga"],
        error: ["dialog-error.wav", "dialog-warning.oga"],
        warning: ["dialog-warning.wav", "dialog-warning.oga"],
        trash: ["trash-move.wav", "trash-empty.oga"],
        trashEmpty: ["trash-empty.wav", "trash-empty.oga"],
        screenshot: ["screen-capture.wav", "camera-shutter.oga"],
        device: ["device-added.wav", "device-added.oga"]
    })
    readonly property var labels: [["startup", "Start-up"], ["notification", "Notification"], ["unlock", "Unlock"], ["lock", "Lock"],
                                   ["plug", "Charger"], ["done", "Done"], ["alarm", "Timer"], ["trash", "Trash"], ["trashEmpty", "Empty Trash"],
                                   ["screenshot", "Screenshot"], ["error", "Error"]]

    property bool haveIslet: true
    Process {
        running: true
        command: ["test", "-f", root.dir + "message-new-instant.wav"]
        onExited: code => root.haveIslet = code === 0
    }

    property real last: 0
    function play(ev, force) {
        if (ev !== "notification" && !Prefs.systemSounds && !force) return;
        if (Date.now() - last < 250 && !force) return;      // không chồng tiếng
        last = Date.now();
        const f = files[ev] || files.notification;
        Quickshell.execDetached(["pw-play", "--volume", "0.7", haveIslet ? dir + f[0] : fallback + f[1]]);
    }

    // tiếng bật máy: một lần mỗi phiên đăng nhập (shell nạp lại thì không kêu lại)
    function startupOnce() {
        if (!Prefs.systemSounds) return;
        mark.running = true;
    }
    Process {
        id: mark
        command: ["sh", "-c", "f=\"${XDG_RUNTIME_DIR:-/tmp}/islet-started\"; [ -e \"$f\" ] && exit 1; : > \"$f\""]
        onExited: code => { if (code === 0) startT.start(); }
    }
    Timer { id: startT; interval: 1200; onTriggered: root.play("startup") }
}
