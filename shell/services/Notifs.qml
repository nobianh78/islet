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

    // Lịch sử cho trung tâm thông báo (bản sao thuần, còn lại kể cả khi app đã đóng thông báo).
    // Mới nhất đứng đầu, giữ tối đa 60 cái.
    property var history: []
    property int unread: 0
    property int nextId: 1
    function remember(n) {
        const icon = iconFor(n);
        const item = {
            uid: nextId++,
            app: n.appName || "Apps",
            summary: n.summary || "",
            body: (n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(),
            icon: icon,
            time: new Date(),
            critical: n.urgency === NotificationUrgency.Critical,
            actions: (n.actions || []).map(a => ({ id: a.identifier, text: a.text })),
            ref: n
        };
        history = [item].concat(history).slice(0, 60);
        unread += 1;
    }
    function dismiss(uid) {
        const it = history.find(h => h.uid === uid);
        try { it?.ref?.dismiss(); } catch (e) {}
        history = history.filter(h => h.uid !== uid);
    }
    function clearApp(app) { history.filter(h => h.app === app).forEach(h => { try { h.ref?.dismiss(); } catch (e) {} }); history = history.filter(h => h.app !== app); }
    function clearAll() { history.forEach(h => { try { h.ref?.dismiss(); } catch (e) {} }); history = []; unread = 0; }
    function invoke(uid, actionId) {
        const it = history.find(h => h.uid === uid);
        const a = (it?.ref?.actions || []).find(x => x.identifier === actionId);
        try { a?.invoke(); } catch (e) {}
    }

    NotificationServer {
        id: server
        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        bodyMarkupSupported: false

        onNotification: n => {
            n.tracked = true;
            root.latest = n;
            root.remember(n);
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
