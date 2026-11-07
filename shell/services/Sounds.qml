pragma Singleton
import QtQuick
import Quickshell
import "../theme"

// Âm thanh hệ thống (bộ freedesktop): thông báo · khoá / mở máy · cắm / rút sạc · hết giờ.
// Tắt hết trong Cài đặt › Sound (Prefs.systemSounds); tiếng thông báo riêng: Prefs.notifSounds.
Singleton {
    readonly property string dir: "/usr/share/sounds/freedesktop/stereo/"
    readonly property var files: ({
        notification: "message-new-instant.oga", lock: "device-removed.oga", unlock: "service-login.oga",
        plug: "power-plug.oga", unplug: "power-unplug.oga", done: "complete.oga", error: "dialog-warning.oga"
    })
    property real last: 0
    function play(ev) {
        if (ev !== "notification" && !Prefs.systemSounds) return;
        if (Date.now() - last < 300) return;      // không chồng tiếng
        last = Date.now();
        Quickshell.execDetached(["pw-play", "--volume", "0.7", dir + (files[ev] || files.notification)]);
    }
}
