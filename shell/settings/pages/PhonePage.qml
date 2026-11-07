import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import ".."
// Cài đặt › Phone — điện thoại nối với Islet qua KDE Connect (lệnh islet-phone):
// ghép đôi, pin, đổ chuông, gửi file (thả file lên thẻ điện thoại), gửi clipboard.
// Thông báo từ điện thoại tự hiện trên Dynamic Island; clipboard tự đồng bộ hai chiều.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12

    property var devices: []
    property bool installed: true
    property bool loaded: false
    property string myName: ""
    property string msg: ""
    function say(t) { msg = t; msgClear.restart(); }
    Timer { id: msgClear; interval: 5000; onTriggered: page.msg = "" }

    onVisibleChanged: if (visible) { act(["refresh"]); lst.running = true; nm.running = true; }
    Timer { interval: 3000; repeat: true; running: page.visible; onTriggered: lst.running = true }

    Process {
        id: lst
        command: ["islet-phone", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text || "[]");
                    page.installed = d !== null;
                    page.devices = d || [];
                } catch (e) { page.devices = []; }
                page.loaded = true;
            }
        }
    }
    Process { id: nm; command: ["islet-phone", "name"]; stdout: StdioCollector { onStreamFinished: page.myName = text.trim() } }

    Component { id: runner; Process {} }
    function act(args, okText) {
        const p = runner.createObject(page, { command: ["islet-phone"].concat(args) });
        p.exited.connect(code => { if (okText) page.say(code === 0 ? okText : "That didn't work — is the phone nearby?"); lst.running = true; p.destroy(); });
        p.running = true;
    }

    // ---------- chưa cài KDE Connect ----------
    Card {
        visible: !page.installed
        width: parent.width; height: 96
        Icon { x: 22; anchors.verticalCenter: parent.verticalCenter; name: "phone"; size: 30 }
        Column {
            x: 68; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 220
            Text { text: "Phone link needs KDE Connect"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: "A small free app that links your phone and this computer."; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
        Pill {
            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
            label: "Install"; primary: true
            onClicked: Packages.enqueue("kdeconnect", "KDE Connect", "install", "", ["kdeconnect"])
        }
    }

    // ---------- chưa có điện thoại ----------
    Card {
        visible: page.installed && page.loaded && page.devices.length === 0
        width: parent.width
        height: setupCol.implicitHeight + 36
        Column {
            id: setupCol
            x: 22; y: 18
            width: parent.width - 44
            spacing: 10
            Row {
                spacing: 12
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "phone"; size: 26 }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Link your phone"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.Bold }
            }
            Repeater {
                model: [
                    "Install KDE Connect on your phone — Android: Play Store or F-Droid · iPhone: App Store.",
                    "Connect the phone to the same Wi-Fi as this computer.",
                    "Open KDE Connect on the phone, tap “" + (page.myName || "this computer") + "” and choose Pair.",
                    "Accept the request here when it shows up."
                ]
                Row {
                    required property string modelData
                    required property int index
                    spacing: 10
                    Rectangle {
                        width: 22; height: 22; radius: 11; color: Theme.tint(0.25)
                        Text { anchors.centerIn: parent; text: parent.parent.index + 1; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold }
                    }
                    Text { width: setupCol.width - 32; wrapMode: Text.Wrap; text: parent.modelData; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Text { text: "Looking for phones…"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
    }

    // ---------- điện thoại ----------
    Repeater {
        model: page.devices
        Card {
            id: card
            required property var modelData
            readonly property var d: modelData
            readonly property bool live: d.paired && d.reachable
            width: page.width
            height: 86 + (live ? 50 : 0)
            border.width: drop.containsDrag ? 2 : 1
            border.color: drop.containsDrag ? Theme.accent : Qt.rgba(1, 1, 1, 0.05)

            // thả file lên thẻ = gửi sang điện thoại
            DropArea {
                id: drop
                anchors.fill: parent
                enabled: card.live
                keys: ["text/uri-list"]
                onDropped: e => {
                    const files = e.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(x => x.startsWith("/"));
                    page.act(["send", card.d.id].concat(files), files.length === 1 ? "Sent " + files[0].split("/").pop() : "Sent " + files.length + " files");
                    e.acceptProposedAction();
                }
            }

            Rectangle {
                x: 18; y: 18; width: 50; height: 50; radius: 16
                color: card.live ? Theme.tint(0.25) : Qt.rgba(1, 1, 1, 0.07)
                Icon { anchors.centerIn: parent; name: card.d.type === "tablet" ? "device" : "phone"; size: 24 }
            }
            Column {
                x: 82; y: 22
                width: parent.width - 82 - btns.width - 30
                spacing: 3
                Text { width: parent.width; elide: Text.ElideRight; text: card.d.name; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: card.d.incoming ? "Wants to pair with this computer"
                        : card.d.requested ? "Waiting for the phone to accept…"
                        : !card.d.paired ? (card.d.reachable ? "Nearby · not paired" : "Not nearby")
                        : !card.d.reachable ? "Paired · not nearby"
                        : "Connected" + (card.d.battery >= 0 ? "  ·  " + card.d.battery + "%" + (card.d.charging ? " charging" : "") : "")
                    color: card.d.incoming ? Qt.lighter(Theme.accent, 1.3) : card.live ? "#34C77B" : "#8E8E93"
                    font.family: Theme.font; font.pixelSize: 12
                }
            }
            Row {
                id: btns
                anchors.right: parent.right; anchors.rightMargin: 18
                y: 28
                spacing: 8
                Pill { visible: card.d.incoming; label: "Accept"; primary: true; onClicked: page.act(["accept", card.d.id], "Paired with " + card.d.name) }
                Pill { visible: card.d.incoming; label: "Reject"; onClicked: page.act(["reject", card.d.id]) }
                Pill { visible: !card.d.paired && !card.d.incoming && card.d.reachable && !card.d.requested; label: "Pair"; primary: true; onClicked: page.act(["pair", card.d.id], "Check your phone to accept") }
                Pill { visible: card.d.paired; label: "Unpair"; onClicked: page.act(["unpair", card.d.id], "Unpaired " + card.d.name) }
            }
            // việc làm được khi đã nối
            Row {
                visible: card.live
                x: 82; y: 86
                spacing: 8
                Pill { label: "Ring phone"; onClicked: page.act(["ring", card.d.id], "Ringing " + card.d.name) }
                Pill { label: "Send clipboard"; onClicked: page.act(["clip", card.d.id], "Clipboard sent") }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Drop files here to send them"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            }
        }
    }

    Text { visible: page.msg !== ""; text: page.msg; color: "#34C77B"; font.family: Theme.font; font.pixelSize: 12 }

    // ---------- có gì ----------
    SectionLabel { visible: page.installed; text: "When your phone is linked" }
    Card {
        visible: page.installed
        width: parent.width
        height: featCol.implicitHeight + 24
        Column {
            id: featCol
            x: 18; y: 12
            width: parent.width - 36
            Repeater {
                model: [
                    ["bell", "Phone notifications show up on the Dynamic Island"],
                    ["clipboard", "Copy on one, paste on the other — the clipboard is shared"],
                    ["folder", "Files › right-click › Scripts › Send to Phone; files from the phone land in Downloads"],
                    ["volume", "Music pauses when a call comes in"]
                ]
                Item {
                    required property var modelData
                    width: featCol.width; height: 36
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.modelData[0]; size: 15; opacity: 0.8 }
                    Text { x: 28; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 28; elide: Text.ElideRight; text: parent.modelData[1]; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 13 }
                }
            }
        }
    }
    Hint { visible: page.installed; text: "If the phone can't find this computer, check that both are on the same Wi-Fi. With the firewall on, Islet keeps the KDE Connect ports (1714–1764) open on your network." }
}
