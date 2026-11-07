pragma Singleton
import QtQuick
import Quickshell
import "../theme"

// Đưa cài đặt giao diện / trợ năng sang app GTK (gsettings) và con trỏ (hyprctl setcursor).
Singleton {
    id: root
    readonly property string sig: [Prefs.textScale, Prefs.highContrast, Prefs.cursorSize, Prefs.fontFamily, Prefs.reduceMotion, Prefs.systemSounds].join("|")
    onSigChanged: if (Prefs.loaded) later.restart()
    Component.onCompleted: later.restart()
    Timer {
        id: later
        interval: 600
        onTriggered: {
            const g = (schema, key, val) => Quickshell.execDetached(["gsettings", "set", schema, key, String(val)]);
            g("org.gnome.desktop.interface", "text-scaling-factor", Prefs.textScale);
            g("org.gnome.desktop.a11y.interface", "high-contrast", Prefs.highContrast);
            g("org.gnome.desktop.interface", "cursor-theme", "Islet-Cursors");
            g("org.gnome.desktop.interface", "color-scheme", "prefer-dark");      // Islet chỉ có giao diện tối: Files, Quick Look… theo
            g("org.gnome.desktop.interface", "cursor-size", Prefs.cursorSize);
            g("org.gnome.desktop.interface", "font-name", Prefs.fontFamily + " 11");
            g("org.gnome.desktop.interface", "enable-animations", !Prefs.reduceMotion);
            g("org.gnome.desktop.sound", "theme-name", "islet");                       // app GTK dùng bộ âm thanh Islet
            g("org.gnome.desktop.sound", "event-sounds", Prefs.systemSounds);
            Quickshell.execDetached(["hyprctl", "setcursor", "Islet-Cursors", String(Prefs.cursorSize)]);
        }
    }
}
