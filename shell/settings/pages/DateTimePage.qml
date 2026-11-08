import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."

// Cài đặt › Date & Time: múi giờ, đồng bộ giờ qua mạng, đồng hồ 24 giờ, hiện giây.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12

    property string tz: ""
    property bool ntp: true
    property var zones: []
    property string query: ""
    property string err: ""
    onVisibleChanged: if (visible) { info.running = true; if (!zones.length) list.running = true; }
    Process {
        id: info
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "--value"]
        stdout: StdioCollector { onStreamFinished: { const l = text.trim().split("\n"); page.tz = l[0] || ""; page.ntp = l[1] === "yes"; } }
    }
    Process { id: list; command: ["timedatectl", "list-timezones"]; stdout: StdioCollector { onStreamFinished: page.zones = text.trim().split("\n") } }
    readonly property var matches: query.trim().length < 2 ? [] : zones.filter(z => z.toLowerCase().replace(/_/g, " ").indexOf(query.trim().toLowerCase()) >= 0).slice(0, 8)

    Card {
        width: parent.width
        height: 84
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: Time.time; color: Theme.label; font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Bold }
            Text { text: Time.dateLong + " · " + (page.tz || "…"); color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
        }
    }

    Card {
        width: parent.width; height: 58
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Set time automatically"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: "Sync the clock with internet time servers"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
        }
        Toggle {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            checked: page.ntp
            onToggled: Admin.run(["ntp", page.ntp ? "off" : "on"], (ok, out) => { page.err = ok ? "" : out; info.running = true; })
        }
    }

    SectionLabel { text: "Time zone" }
    Card {
        width: parent.width
        height: tzCol.implicitHeight + 28
        Column {
            id: tzCol
            x: 18; y: 14
            width: parent.width - 36
            spacing: 8
            Rectangle {
                width: parent.width; height: 36; radius: 12
                color: Theme.fg(0.07)
                border.width: 1; border.color: tzIn.activeFocus ? Theme.tint(0.6) : Theme.fg(0.06)
                TIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; opacity: 0.6 }
                TextInput { id: tzIn; x: 32; width: parent.width - 42; height: parent.height; verticalAlignment: TextInput.AlignVCenter; color: Theme.label; font.family: Theme.font; font.pixelSize: 13; onTextChanged: page.query = text }
                Text { visible: tzIn.text === ""; x: 32; anchors.verticalCenter: parent.verticalCenter; text: "Search a city — e.g. Ho Chi Minh, Tokyo, London"; color: Theme.faint; font.family: Theme.font; font.pixelSize: 12 }
            }
            Repeater {
                model: page.matches
                Rectangle {
                    required property string modelData
                    width: tzCol.width; height: 36; radius: 10
                    color: zm.containsMouse ? Theme.fg(0.08) : "transparent"
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.replace(/_/g, " ").replace("/", " › "); color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                    Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; visible: parent.modelData === page.tz; text: "Current"; color: Qt.lighter(Theme.accent, 1.3); font.family: Theme.font; font.pixelSize: 11 }
                    MouseArea {
                        id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Admin.run(["timezone", parent.modelData], (ok, out) => { page.err = ok ? "" : out; info.running = true; if (ok) tzIn.text = ""; })
                    }
                }
            }
        }
    }
    Text { visible: page.err !== ""; text: page.err; color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }

    SectionLabel { text: "Clock" }
    Card {
        width: parent.width
        height: 116
        Column {
            x: 0; y: 4; width: parent.width
            Item {
                width: parent.width; height: 54
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "24-hour time"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Prefs.clock24; onToggled: Prefs.set("clock24", !Prefs.clock24) }
            }
            Item {
                width: parent.width; height: 54
                Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "Show seconds"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Prefs.clockSeconds; onToggled: Prefs.set("clockSeconds", !Prefs.clockSeconds) }
            }
        }
    }
}
