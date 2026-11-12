import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import ".."
// Cài đặt › Windows apps: chạy app Windows (Wine ẩn bên trong, qua islet-win), xem app đã cài, xoá môi trường.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool ready: false
    property string version: ""
    property var apps: []          // { file, name }
    property var envs: []          // { name, size }
    onVisibleChanged: if (visible) refresh()
    function refresh() { doc.running = true; lsApps.running = true; lsEnvs.running = true; }
    function rows(t) { return t.split("\n").filter(x => x).map(l => l.split("\t")); }

    Process { id: doc; command: ["islet-win", "doctor"]; stdout: StdioCollector { onStreamFinished: { page.ready = text.startsWith("wine "); page.version = text.trim(); } } }
    Process { id: lsApps; command: ["islet-win", "apps"]; stdout: StdioCollector { onStreamFinished: page.apps = page.rows(text).map(p => ({ file: p[0], name: p[1] })) } }
    Process { id: lsEnvs; command: ["islet-win", "prefixes"]; stdout: StdioCollector { onStreamFinished: page.envs = page.rows(text).map(p => ({ name: p[0], size: p[1] })) } }

    Card {
        width: parent.width; height: 70
        Column {
            anchors.verticalCenter: parent.verticalCenter; x: 18; width: parent.width - 36; spacing: 2
            Text { text: page.ready ? "Windows programs are ready" : "Windows programs aren't available"; color: Theme.label; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: page.ready ? "Double-click a .exe or .msi file in Files to run it. Not every Windows program works." : "This system doesn't include the Windows compatibility layer."
                color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
            }
        }
    }

    SectionLabel { text: "Popular programs"; visible: page.ready }
    Card {
        visible: page.ready
        width: parent.width; height: pCol.implicitHeight + 8
        Column {
            id: pCol
            y: 4; width: parent.width
            Repeater {
                model: [
                    { name: "7-Zip", sub: "Archives (checked on Islet)", url: "https://www.7-zip.org/download.html" },
                    { name: "Notepad++", sub: "Text and code editor", url: "https://notepad-plus-plus.org/downloads/" },
                    { name: "IrfanView", sub: "Fast image viewer", url: "https://www.irfanview.com/" },
                    { name: "foobar2000", sub: "Music player", url: "https://www.foobar2000.org/windows" }
                ]
                Item {
                    id: pr
                    required property var modelData
                    required property int index
                    width: pCol.width; height: 54
                    Rectangle { visible: pr.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    Column {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        Text { text: pr.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: pr.modelData.sub; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    Pill {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        label: "Download page"
                        onClicked: Quickshell.execDetached(["xdg-open", pr.modelData.url])
                    }
                }
            }
        }
    }
    Text {
        visible: page.ready
        width: parent.width; wrapMode: Text.WordWrap
        text: "Download the installer from the official page, then double-click it in Files. Compatibility varies from program to program."
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
    }

    SectionLabel { text: "Installed programs"; visible: page.ready }
    Card {
        visible: page.ready
        width: parent.width; height: aCol.implicitHeight + 8
        Column {
            id: aCol
            y: 4; width: parent.width
            Text { visible: page.apps.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "Nothing installed yet — open a Windows installer (setup.exe)"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.apps
                Item {
                    id: ar
                    required property var modelData
                    required property int index
                    width: aCol.width; height: 52
                    Rectangle { visible: ar.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    Text { x: 18; width: parent.width - 110; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: ar.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                    Pill {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        label: "Open"
                        onClicked: Quickshell.execDetached(["gio", "launch", Quickshell.env("HOME") + "/.local/share/applications/wine/" + ar.modelData.file])
                    }
                }
            }
        }
    }

    SectionLabel { text: "Windows environments"; visible: page.ready }
    Card {
        visible: page.ready
        width: parent.width; height: eCol.implicitHeight + 8
        Column {
            id: eCol
            y: 4; width: parent.width
            Text { visible: page.envs.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "None yet — one is made the first time you run a Windows program"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.envs
                Item {
                    id: er
                    required property var modelData
                    required property int index
                    width: eCol.width; height: 56
                    Rectangle { visible: er.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    Column {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        Text { text: er.modelData.name === "default" ? "Default" : er.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: er.modelData.size + " · removing it deletes the programs and data inside"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    Pill {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        label: "Remove"
                        onClicked: { Quickshell.execDetached(["islet-win", "reset", er.modelData.name]); later.restart(); }
                    }
                }
            }
        }
    }
    Timer { id: later; interval: 800; onTriggered: page.refresh() }
}
