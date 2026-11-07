import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Printers: dịch vụ in (CUPS), máy in tìm thấy, đặt mặc định, in thử, thêm máy in.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool cups: false
    property var printers: []     // { name, state, isDefault }
    property string msg: ""
    onVisibleChanged: if (visible) refresh()
    function refresh() { st.running = true; }
    Process {
        id: st
        command: ["sh", "-c", 'systemctl is-active cups 2>/dev/null; d=$(lpstat -d 2>/dev/null | sed -n "s/.*: //p"); lpstat -p 2>/dev/null | awk -v d="$d" "/^printer/ {n=\\$2; s=(\\$0 ~ /idle/)?\\"Ready\\":(\\$0 ~ /disabled/)?\\"Paused\\":\\"Printing\\"; print \\"P\\t\\" n \\"\\t\\" s \\"\\t\\" (n==d)}"']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                page.cups = l[0] === "active";
                page.printers = l.slice(1).filter(x => x.startsWith("P\t")).map(x => { const p = x.split("\t"); return { name: p[1], state: p[2], isDefault: p[3] === "1" }; });
            }
        }
    }
    Card {
        width: parent.width; height: 58
        Row2 {
            title: "Printing"
            sub: page.cups ? "On — printers on your network are found automatically" : "Off"
            checked: page.cups
            onToggled: {
                const op = page.cups ? "off" : "on";
                Admin.run(["service", op, "cups"], (ok, out) => {
                    if (!ok) { page.msg = out; page.refresh(); return; }
                    Admin.run(["service", op, "avahi-daemon"], () => Admin.run(["service", op, "cups-browsed"], () => page.refresh()));
                });
            }
        }
    }
    SectionLabel { text: "Printers"; visible: page.cups }
    Card {
        visible: page.cups
        width: parent.width
        height: pCol.implicitHeight + 8
        Column {
            id: pCol
            y: 4; width: parent.width
            Text { visible: page.printers.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "No printers yet — turn on your printer or add one"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.printers
                Item {
                    id: pr
                    required property var modelData
                    required property int index
                    width: pCol.width; height: 56
                    Rectangle { visible: pr.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                    Rectangle { x: 16; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 10; color: Qt.rgba(1, 1, 1, 0.08); Icon { anchors.centerIn: parent; name: "document"; size: 16 } }
                    Column {
                        x: 60; anchors.verticalCenter: parent.verticalCenter
                        Text { text: pr.modelData.name.replace(/_/g, " "); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: pr.modelData.state + (pr.modelData.isDefault ? " · Default" : ""); color: pr.modelData.isDefault ? Qt.lighter(Theme.accent, 1.3) : "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Pill { visible: !pr.modelData.isDefault; label: "Make default"; onClicked: { Quickshell.execDetached(["lpoptions", "-d", pr.modelData.name]); later.restart(); } }
                        Pill { label: "Print test page"; onClicked: { Quickshell.execDetached(["lp", "-d", pr.modelData.name, "/usr/share/cups/data/testprint"]); page.msg = "Test page sent to " + pr.modelData.name; } }
                    }
                }
            }
        }
    }
    Timer { id: later; interval: 600; onTriggered: page.refresh() }
    Row {
        visible: page.cups
        spacing: 10
        Pill { label: "Add a printer…"; primary: true; onClicked: Quickshell.execDetached(["system-config-printer"]) }
        Pill { label: "Refresh"; onClicked: page.refresh() }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
    Hint { text: "Islet also adds a “Save as PDF” printer, so any app can print to a PDF file." }
}
