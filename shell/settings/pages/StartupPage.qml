import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Startup Apps: app tự mở khi đăng nhập (~/.config/autostart, chạy bởi islet-autostart).
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/autostart"
    property var items: []          // { file, id, name, on }
    property bool adding: false
    property string q: ""
    onVisibleChanged: if (visible) load.running = true
    Process {
        id: load
        command: ["sh", "-c", 'mkdir -p "$0"; for f in "$0"/*.desktop; do [ -f "$f" ] || continue; n=$(grep -m1 "^Name=" "$f" | cut -d= -f2-); d=0; grep -qiE "^(Hidden|X-Islet-Disabled)=true" "$f" && d=1; printf "%s\\t%s\\t%s\\n" "$(basename "$f")" "$n" "$d"; done', page.dir]
        stdout: StdioCollector { onStreamFinished: page.items = text.split("\n").filter(x => x).map(l => { const p = l.split("\t"); return { id: p[0], name: p[1] || p[0], on: p[2] !== "1" }; }) }
    }
    // tên file luôn đi qua tham số $1 (không ghép vào câu lệnh)
    function run(sh, arg) { act.command = ["sh", "-c", sh, page.dir, arg || ""]; act.running = true; }
    Process { id: act; onExited: load.running = true }
    function add(e) {
        run('src=""; for d in "$HOME/.local/share/applications" /usr/local/share/applications /usr/share/applications; do [ -f "$d/$1.desktop" ] && src="$d/$1.desktop" && break; done; [ -n "$src" ] && cp "$src" "$0/$1.desktop"', e.id);
        adding = false;
    }
    function setOn(it, on) {
        run('f="$0/$1"; sed -i "/^X-Islet-Disabled=/d;/^Hidden=/d" "$f"; ' + (on ? "true" : 'echo "X-Islet-Disabled=true" >> "$f"'), it.id);
    }
    function remove(it) { run('rm -f -- "$0/$1"', it.id); }
    readonly property var candidates: DesktopEntries.applications.values.filter(e => !e.noDisplay && (!q || e.name.toLowerCase().indexOf(q.toLowerCase()) >= 0)
        && !page.items.some(i => i.id === e.id + ".desktop")).sort((a, b) => a.name.localeCompare(b.name)).slice(0, 30)

    Card {
        width: parent.width
        height: sCol.implicitHeight + 8
        Column {
            id: sCol
            y: 4; width: parent.width
            Text { visible: page.items.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "No apps start automatically"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.items
                Item {
                    id: srow
                    required property var modelData
                    required property int index
                    width: sCol.width; height: 56
                    HoverHandler { id: sh }
                    Rectangle { visible: srow.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    AppIcon {
                        x: 16; anchors.verticalCenter: parent.verticalCenter; size: 30
                        readonly property var e: DesktopEntries.byId(srow.modelData.id.replace(/\.desktop$/, ""))
                        name: Theme.appKey(srow.modelData.id.replace(/\.desktop$/, ""))
                        source: e ? Quickshell.iconPath(e.icon, true) : ""
                    }
                    Text { x: 58; anchors.verticalCenter: parent.verticalCenter; text: srow.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Pill { visible: sh.hovered; label: "Remove"; onClicked: page.remove(srow.modelData) }
                        Toggle { anchors.verticalCenter: parent.verticalCenter; checked: srow.modelData.on; onToggled: page.setOn(srow.modelData, !srow.modelData.on) }
                    }
                }
            }
        }
    }
    Pill { label: page.adding ? "Done" : "Add an app…"; primary: !page.adding; onClicked: page.adding = !page.adding }
    Card {
        visible: page.adding
        width: parent.width
        height: Math.min(addCol.implicitHeight, 320) + 60
        Rectangle {
            x: 14; y: 12; width: parent.width - 28; height: 34; radius: 11
            color: Theme.fg(0.07)
            TextInput { id: qIn; anchors.fill: parent; anchors.leftMargin: 12; verticalAlignment: TextInput.AlignVCenter; color: Theme.label; font.family: Theme.font; font.pixelSize: 13; onTextChanged: page.q = text }
            Text { visible: qIn.text === ""; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Search apps"; color: Theme.faint; font.family: Theme.font; font.pixelSize: 12 }
        }
        Flickable {
            x: 8; y: 54; width: parent.width - 16; height: parent.height - 60
            contentHeight: addCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: addCol
                width: parent.width
                Repeater {
                    model: page.candidates
                    Rectangle {
                        required property var modelData
                        width: addCol.width; height: 40; radius: 10
                        color: am.containsMouse ? Theme.fg(0.08) : "transparent"
                        AppIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; size: 24; name: Theme.appKey(parent.modelData.id); source: Quickshell.iconPath(parent.modelData.icon, true) }
                        Text { x: 44; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.add(parent.modelData) }
                    }
                }
            }
        }
    }
    Hint { text: "Startup apps open a few seconds after you sign in." }
}
