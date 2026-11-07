import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Island & Dock
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    SectionLabel { text: "Dynamic Island" }
    Card {
        width: parent.width
        height: iCol.implicitHeight + 8
        Column {
            id: iCol
            y: 4; width: parent.width
            Row2 { title: "Now playing"; sub: "Album art, title and sound waves while music plays"; checked: Prefs.islandMedia; onToggled: Prefs.set("islandMedia", !Prefs.islandMedia) }
            Row2 { divider: true; title: "Live activities"; sub: "Timers, screen recording and downloads"; checked: Prefs.islandLive; onToggled: Prefs.set("islandLive", !Prefs.islandLive) }
            Row2 { divider: true; title: "Coding agents"; sub: "Claude Code, Codex, Gemini, OpenCode, editors"; checked: Prefs.islandAgents; onToggled: Prefs.set("islandAgents", !Prefs.islandAgents) }
            Row2 { divider: true; title: "Notification banners"; sub: Prefs.dnd ? "Paused by Do Not Disturb" : "Messages slide out of the island"; checked: !Prefs.dnd; onToggled: Prefs.set("dnd", !Prefs.dnd) }
        }
    }
    SectionLabel { text: "Dock" }
    Card {
        width: parent.width; height: 92
        Text { x: 18; y: 14; text: "Icon size"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        Row {
            x: 18; y: 40; spacing: 6
            Repeater {
                model: [[38, "Small"], [46, "Medium"], [54, "Large"], [62, "Huge"]]
                Chip { required property var modelData; label: modelData[1]; on: Prefs.dockSize === modelData[0]; onClicked: Prefs.set("dockSize", modelData[0]) }
            }
        }
        // xem trước cỡ icon
        Row {
            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater { model: ["files", "browser", "terminal"]; Image { required property string modelData; width: Prefs.dockSize * 0.8; height: width; sourceSize: Qt.size(128, 128); source: Theme.appIcon(modelData); Behavior on width { SpringAnimation { spring: 5; damping: 0.35 } } } }
        }
    }
    Card {
        width: parent.width; height: 58
        Row2 { title: "Hide the dock automatically"; sub: "Slides away; move the pointer to the bottom edge to show it"; checked: Prefs.dockAutohide; onToggled: Prefs.set("dockAutohide", !Prefs.dockAutohide) }
    }
}
