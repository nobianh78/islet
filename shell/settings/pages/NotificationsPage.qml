import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Notifications: Không làm phiền (bật / theo giờ), xem trước nội dung, âm báo, tắt từng app.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    readonly property var apps: {
        const seen = {};
        for (const h of Notifs.history) seen[h.app] = true;
        for (const m of Prefs.notifMuted || []) seen[m] = true;
        return Object.keys(seen).sort((a, b) => a.localeCompare(b));
    }
    function muted(a) { return (Prefs.notifMuted || []).indexOf(a) >= 0; }
    function toggleMute(a) {
        const l = (Prefs.notifMuted || []).slice();
        const i = l.indexOf(a);
        if (i >= 0) l.splice(i, 1); else l.push(a);
        Prefs.set("notifMuted", l);
    }

    Card {
        width: parent.width
        height: dCol.implicitHeight + 8
        Column {
            id: dCol
            y: 4; width: parent.width
            Row2 { title: "Do Not Disturb"; sub: Prefs.dnd ? "On — banners are hidden, notifications are kept" : "Off"; checked: Prefs.dnd; onToggled: Prefs.set("dnd", !Prefs.dnd) }
            Row2 { divider: true; title: "Turn on Do Not Disturb on a schedule"; sub: Prefs.dndScheduled ? "Every day " + Prefs.dndFrom + " – " + Prefs.dndTo + (Ui.dndNow ? " · on now" : "") : "Off"; checked: Prefs.dndScheduled; onToggled: Prefs.set("dndScheduled", !Prefs.dndScheduled) }
            Item {
                visible: Prefs.dndScheduled
                width: parent.width; height: 52
                Row {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "From"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                    Repeater { model: ["21:00", "22:00", "23:00", "00:00"]; Chip { required property string modelData; label: modelData; on: Prefs.dndFrom === modelData; onClicked: Prefs.set("dndFrom", modelData) } }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "to"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                    Repeater { model: ["06:00", "07:00", "08:00"]; Chip { required property string modelData; label: modelData; on: Prefs.dndTo === modelData; onClicked: Prefs.set("dndTo", modelData) } }
                }
            }
            Row2 { divider: true; title: "Show message previews"; sub: "Otherwise banners only say “New notification”"; checked: Prefs.notifPreview; onToggled: Prefs.set("notifPreview", !Prefs.notifPreview) }
            Row2 { divider: true; title: "Notification sound"; sub: "A soft chime when a banner appears"; checked: Prefs.notifSounds; onToggled: Prefs.set("notifSounds", !Prefs.notifSounds) }
        }
    }

    SectionLabel { text: "Apps" }
    Card {
        width: parent.width
        height: aCol.implicitHeight + 8
        Column {
            id: aCol
            y: 4; width: parent.width
            Text { visible: page.apps.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "Apps appear here after they send a notification"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.apps
                Row2 { required property string modelData; required property int index; divider: index > 0; title: modelData; sub: page.muted(modelData) ? "Muted — kept in Notification Center only" : "Banners on"; checked: !page.muted(modelData); onToggled: page.toggleMute(modelData) }
            }
        }
    }
}
