import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Workspaces: số desktop trên thanh trên, kiểu chuyển desktop.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    Card {
        width: parent.width; height: 70
        Text { x: 18; y: 14; text: "Desktops in the top bar"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
        Row { x: 18; y: 36; spacing: 6; Repeater { model: [3, 4, 5, 6, 8, 10]; Chip { required property int modelData; label: String(modelData); on: Prefs.wsCount === modelData; onClicked: Prefs.set("wsCount", modelData) } } }
    }
    Card {
        width: parent.width; height: 70
        Text { x: 18; y: 14; text: "Switch animation"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
        Row {
            x: 18; y: 36; spacing: 6
            Repeater {
                model: [["slidefade", "Slide & fade"], ["slide", "Slide"], ["slidevert", "Vertical"], ["fade", "Fade"], ["none", "None"]]
                Chip { required property var modelData; label: modelData[1]; on: Prefs.wsAnim === modelData[0]; onClicked: Prefs.set("wsAnim", modelData[0]) }
            }
        }
    }
    SectionLabel { text: "Shortcuts" }
    Card {
        width: parent.width
        height: sc.implicitHeight + 24
        Column {
            id: sc
            x: 18; y: 12; width: parent.width - 36
            Repeater {
                model: [["Super + 1 … 9", "Go to desktop"], ["Super + Shift + 1 … 9", "Move window to desktop"], ["3 fingers left / right", "Next / previous desktop"], ["Super + scroll", "Next / previous desktop"], ["Super + Tab", "Overview of all windows"]]
                Item {
                    required property var modelData
                    width: sc.width; height: 36
                    Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[0]; color: Theme.label; font.family: Theme.mono; font.pixelSize: 12 }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                }
            }
        }
    }
}
