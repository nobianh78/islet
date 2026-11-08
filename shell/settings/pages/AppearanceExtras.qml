import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Appearance (phần thêm): màu nhấn lấy từ hình nền, font chữ của app.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    SectionLabel { text: "Theme" }
    Card {
        width: parent.width; height: 92
        Row {
            x: 18; y: 14; spacing: 10
            Repeater {
                model: [["dark", "Dark", "#16161F"], ["light", "Light", "#F2F2F7"], ["auto", "Automatic", ""]]
                Chip {
                    required property var modelData
                    label: modelData[1]
                    on: Prefs.themeMode === modelData[0]
                    onClicked: Prefs.set("themeMode", modelData[0])
                }
            }
        }
        Text {
            x: 18; y: 54; width: parent.width - 36; wrapMode: Text.Wrap
            text: Prefs.themeMode === "auto" ? "Light from 6:30 to 18:30, dark at night." : "Windows, panels and Settings change. The island, Dock and top bar stay dark for now."
            color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
        }
    }
    Card {
        width: parent.width; height: 64
        Rectangle { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 15; color: Prefs.autoAccent; border.width: Prefs.accentId === "auto" ? 2 : 0; border.color: Theme.label }
        Column {
            x: 60; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Match the wallpaper"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: "The accent color follows the main color of your wallpaper"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
        }
        Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Prefs.accentId === "auto"; onToggled: Prefs.set("accentId", Prefs.accentId === "auto" ? "violet" : "auto") }
    }
    SectionLabel { text: "Font in apps" }
    Card {
        width: parent.width; height: 70
        Row {
            x: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Repeater {
                model: ["Be Vietnam Pro", "Noto Sans", "JetBrains Mono"]
                Rectangle {
                    required property string modelData
                    readonly property bool on: Prefs.fontFamily === modelData
                    width: fl.implicitWidth + 28; height: 40; radius: 13
                    color: on ? Theme.tint(0.25) : fm.containsMouse ? Theme.fg(0.12) : Theme.fg(0.06)
                    border.width: on ? 2 : 0; border.color: Theme.accent
                    Text { id: fl; anchors.centerIn: parent; text: parent.modelData; color: Theme.label; font.family: parent.modelData; font.pixelSize: 13 }
                    MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.set("fontFamily", parent.modelData) }
                }
            }
        }
    }
    Hint { text: "Islet is designed for dark mode, so a light theme is not available yet." }
}
