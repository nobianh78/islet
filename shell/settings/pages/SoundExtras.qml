import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
import Quickshell.Services.Pipewire
// Cài đặt › Sound (phần thêm): âm lượng riêng từng app, âm thanh hệ thống.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    PwObjectTracker { objects: page.streams }

    SectionLabel { text: "Apps" }
    Card {
        width: parent.width
        height: aCol.implicitHeight + 8
        Column {
            id: aCol
            y: 4; width: parent.width
            Text { visible: page.streams.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "Apps playing sound appear here"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.streams
                Item {
                    id: st
                    required property var modelData
                    required property int index
                    width: aCol.width; height: 62
                    readonly property string app: modelData.properties?.["application.name"] || modelData.description || modelData.name || "App"
                    Rectangle { visible: st.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                    AppIcon {
                        x: 16; anchors.verticalCenter: parent.verticalCenter; size: 30
                        readonly property var e: DesktopEntries.heuristicLookup(st.modelData.properties?.["application.process.binary"] || st.app)
                        name: Theme.appKey(e?.id ?? "")
                        source: e ? Quickshell.iconPath(e.icon, true) : Quickshell.iconPath("audio-x-generic", true)
                    }
                    Text { x: 58; y: 12; text: st.app; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                    Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 12; text: Math.round((st.modelData.audio?.volume ?? 0) * 100) + "%"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                    Rectangle {
                        id: tr
                        x: 58; y: 38; width: parent.width - 58 - 18; height: 6; radius: 3
                        color: Qt.rgba(1, 1, 1, 0.14)
                        Rectangle { width: Math.max(6, tr.width * Math.min(1, st.modelData.audio?.volume ?? 0)); height: parent.height; radius: 3; color: st.modelData.audio?.muted ? "#8E8E93" : Theme.accent }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8; preventStealing: true; cursorShape: Qt.PointingHandCursor
                            function setAt(x) { if (st.modelData.audio) st.modelData.audio.volume = Math.max(0, Math.min(1, x / tr.width)); }
                            onPressed: m => setAt(m.x - 8)
                            onPositionChanged: m => { if (pressed) setAt(m.x - 8); }
                        }
                    }
                }
            }
        }
    }

    SectionLabel { text: "System sounds" }
    Card {
        width: parent.width; height: 58
        Row2 { title: "Play system sounds"; sub: "Lock and unlock, plugging in the charger, timers"; checked: Prefs.systemSounds; onToggled: Prefs.set("systemSounds", !Prefs.systemSounds) }
    }
    Row {
        spacing: 8
        visible: Prefs.systemSounds
        Repeater {
            model: [["notification", "Notification"], ["unlock", "Unlock"], ["lock", "Lock"], ["plug", "Charger"], ["done", "Timer"]]
            Pill { required property var modelData; label: "▶ " + modelData[1]; onClicked: { Sounds.last = 0; Sounds.play(modelData[0]); } }
        }
    }
}
