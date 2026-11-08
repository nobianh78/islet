import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Privacy & Security: app đã dùng micro / camera, tường lửa, xoá lịch sử clipboard và tệp gần đây.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool fw: false
    property bool fwKnown: false
    property string msg: ""
    onVisibleChanged: if (visible) fwProc.running = true
    Process {
        id: fwProc
        command: ["systemctl", "is-active", "ufw"]
        stdout: StdioCollector { onStreamFinished: { page.fw = text.trim() === "active"; page.fwKnown = true; } }
    }
    function ago(t) { const s = (Date.now() - t) / 1000; return s < 60 ? "just now" : s < 3600 ? Math.floor(s / 60) + " min ago" : Math.floor(s / 3600) + " h ago"; }

    SectionLabel { text: "Camera & microphone" }
    Card {
        width: parent.width
        height: pCol.implicitHeight + 8
        Column {
            id: pCol
            y: 4; width: parent.width
            Item {
                width: parent.width; height: 50
                Row {
                    x: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 16
                    Row { spacing: 6; Rectangle { width: 8; height: 8; radius: 4; color: Privacy.mic ? "#FF9F0A" : Theme.fg(0.25); anchors.verticalCenter: parent.verticalCenter } Text { text: Privacy.mic ? "Microphone in use · " + Privacy.micApps.join(", ") : "Microphone not in use"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 } }
                    Row { spacing: 6; Rectangle { width: 8; height: 8; radius: 4; color: Privacy.camera ? "#30D158" : Theme.fg(0.25); anchors.verticalCenter: parent.verticalCenter } Text { text: Privacy.camera ? "Camera in use · " + Privacy.camApps.join(", ") : "Camera not in use"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 } }
                }
            }
            Repeater {
                model: Privacy.history
                Item {
                    required property var modelData
                    width: pCol.width; height: 38
                    Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    TIcon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: parent.modelData.what === "camera" ? "camera" : "mic"; size: 14 }
                    Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.app + " used the " + parent.modelData.what; color: Theme.labelSoft; font.family: Theme.font; font.pixelSize: 12 }
                    Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: page.ago(parent.modelData.time); color: Theme.faint; font.family: Theme.font; font.pixelSize: 11 }
                }
            }
        }
    }

    SectionLabel { text: "Security" }
    Card {
        width: parent.width; height: 58
        Row2 {
            title: "Firewall"
            sub: !page.fwKnown ? "…" : page.fw ? "On — blocks incoming connections" : "Off"
            checked: page.fw
            onToggled: Admin.run(["firewall", page.fw ? "off" : "on"], (ok, out) => { page.msg = ok ? "" : out; fwProc.running = true; })
        }
    }

    SectionLabel { text: "History" }
    Card {
        width: parent.width; height: 116
        Column {
            y: 4; width: parent.width
            Item {
                width: parent.width; height: 54
                Column { x: 18; anchors.verticalCenter: parent.verticalCenter; Text { text: "Clipboard history"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 } Text { text: Clipboard.items.length + " items · pinned items are kept"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 } }
                Pill { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; label: "Clear"; onClicked: { Clipboard.clear(); page.msg = "Clipboard history cleared"; } }
            }
            Item {
                width: parent.width; height: 54
                Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                Column { x: 18; anchors.verticalCenter: parent.verticalCenter; Text { text: "Recent files"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 } Text { text: "The list of recently opened files in Files and apps"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 } }
                Pill {
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; label: "Clear"
                    onClicked: { Quickshell.execDetached(["sh", "-c", 'f="$HOME/.local/share/recently-used.xbel"; [ -f "$f" ] && printf "%s\\n" "<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>" "<xbel version=\\"1.0\\"/>" > "$f"']); page.msg = "Recent files cleared"; }
                }
            }
        }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
}
