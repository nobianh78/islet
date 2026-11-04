pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Máy chủ thông báo của Islet (thay cho mako/dunst). Thông báo mới hiện trên island.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    property Notification latest: null

    signal arrived(Notification n)

    NotificationServer {
        id: server
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        bodyMarkupSupported: false

        onNotification: n => {
            n.tracked = true;
            root.latest = n;
            root.arrived(n);
        }
    }

    function iconFor(n) {
        if (!n) return "";
        if (n.image) return n.image;
        if (n.appIcon) {
            if (n.appIcon.startsWith("/") || n.appIcon.startsWith("file:")) return n.appIcon;
            return Quickshell.iconPath(n.appIcon, true);
        }
        return "";
    }
}
