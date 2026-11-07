import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."

// Cài đặt › Keyboard & Language: gõ tiếng Việt (fcitx5 + Bamboo), bố cục bàn phím, lặp phím.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12

    SectionLabel { text: "Vietnamese typing" }
    Card {
        width: parent.width
        height: 64
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Vietnamese input"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: Ime.running ? (Ime.vietnamese ? "On · typing Vietnamese" : "On · typing English") : Prefs.imeEnabled ? "Starting…" : "Off"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
        }
        Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: Prefs.imeEnabled; onToggled: Ime.setEnabled(!Prefs.imeEnabled) }
    }
    Card {
        visible: Prefs.imeEnabled
        width: parent.width
        height: imCol.implicitHeight + 32
        Column {
            id: imCol
            x: 18; y: 16
            width: parent.width - 36
            spacing: 12
            Text { text: "Typing method"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: Ime.methods
                    Chip { required property string modelData; label: modelData; on: Prefs.imeMethod === modelData; onClicked: Ime.setMethod(modelData) }
                }
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: Prefs.imeMethod === "VNI" ? "VNI: type numbers after letters — tie6ng Vie65t → tiếng Việt"
                    : Prefs.imeMethod.indexOf("Telex") === 0 ? "Telex: tieesng Vieejt → tiếng Việt  ·  aw ă · aa â · dd đ · s f r x j = sắc huyền hỏi ngã nặng"
                    : "VIQR: tie^'ng Vie^.t → tiếng Việt"
                color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
            }
            Row {
                spacing: 10
                Rectangle { width: kbd.implicitWidth + 16; height: 26; radius: 7; color: Qt.rgba(1, 1, 1, 0.1); Text { id: kbd; anchors.centerIn: parent; text: "Ctrl + Space"; color: "#FFFFFF"; font.family: Theme.mono; font.pixelSize: 12 } }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "switches Vietnamese ⇄ English · or click VI / EN in the top bar"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            }
            // ô thử gõ
            Rectangle {
                width: parent.width; height: 38; radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1; border.color: tryIn.activeFocus ? Theme.tint(0.6) : Qt.rgba(1, 1, 1, 0.08)
                TextInput { id: tryIn; anchors.fill: parent; anchors.margins: 10; verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14 }
                Text { visible: tryIn.text === "" && !tryIn.activeFocus; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "Try typing here…"; color: "#636366"; font.family: Theme.font; font.pixelSize: 13 }
            }
        }
    }

    SectionLabel { text: "Keyboard" }
    Card {
        width: parent.width
        height: kCol.implicitHeight + 32
        Column {
            id: kCol
            x: 18; y: 16
            width: parent.width - 36
            spacing: 12
            Text { text: "Layout"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [["us", "English (US)"], ["gb", "English (UK)"], ["fr", "French"], ["de", "German"], ["jp", "Japanese"], ["kr", "Korean"]]
                    Chip { required property var modelData; label: modelData[1]; on: Prefs.kbLayout === modelData[0].replace("(intl)", ""); onClicked: Prefs.set("kbLayout", modelData[0].replace("(intl)", "")) }
                }
            }
        }
    }
    Slider {
        width: parent.width
        title: "Key repeat delay"
        label: v => Math.round((150 + v * 750) / 10) * 10 + " ms"
        value: (Prefs.repeatDelay - 150) / 750
        fill: Theme.accent
        onMoved: v => Prefs.set("repeatDelay", Math.round((150 + v * 750) / 10) * 10)
    }
    Slider {
        width: parent.width
        title: "Key repeat speed"
        label: v => Math.round(10 + v * 50) + " / s"
        value: (Prefs.repeatRate - 10) / 50
        fill: Theme.accent
        onMoved: v => Prefs.set("repeatRate", Math.round(10 + v * 50))
    }
    Hint { text: "The Islet interface is in English. Apps follow your typing method and keyboard layout right away." }
}
