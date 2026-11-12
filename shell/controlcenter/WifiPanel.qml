import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"
import "../common"

// Wi-Fi nhanh: danh sách mạng, bấm để nối (hỏi mật khẩu ngay trong bảng nếu cần).
QuickPanel {
    id: root
    title: "Wi-Fi"
    on: !Net.wifiBlocked
    onSwitched: Net.toggleWifi()

    property var nets: []
    property string joining: ""      // mạng đang chờ nhập mật khẩu
    property string busy: ""
    property string error: ""

    Component.onCompleted: { Quickshell.execDetached(["islet-wifi", "scan"]); rescan.restart(); }
    Timer { id: rescan; interval: 2000; onTriggered: list.running = true }
    Timer { interval: 8000; repeat: true; running: root.visible; onTriggered: list.running = true }
    Process {
        id: list
        command: ["islet-wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.nets = text.split("\n").filter(x => x).map(l => {
                const p = l.split("\t");
                return { name: p[0], sec: p[1], q: parseInt(p[2]) || 0, cur: p[3] === "1", saved: p[4] === "1" };
            }).sort((a, b) => (b.cur - a.cur) || (b.q - a.q)).slice(0, 7)
        }
    }
    Process {
        id: con
        property string name: ""
        property string pw: ""
        command: ["islet-wifi", "connect", name]
        stdinEnabled: true
        onStarted: { write(pw + "\n"); stdinEnabled = false; }
        stderr: StdioCollector { id: conErr }
        onExited: code => {
            stdinEnabled = true;
            if (code === 0) { root.joining = ""; root.error = ""; }
            else if (code === 3) { root.joining = root.busy; root.error = "Wrong password"; }
            else root.error = conErr.text.trim() || "Couldn't connect";
            root.busy = "";
            list.running = true; Net.refresh();
        }
    }
    function connectTo(name, pw) { busy = name; error = ""; con.name = name; con.pw = pw || ""; con.running = true; }

    Text {
        visible: !Net.wifiPresent
        width: parent.width; wrapMode: Text.WordWrap
        text: "This computer has no Wi-Fi"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    Text {
        visible: Net.wifiPresent && root.nets.length === 0
        text: Net.wifiBlocked ? "Wi-Fi is off" : "Looking for networks…"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
    }
    Repeater {
        model: root.nets
        Column {
            id: row
            required property var modelData
            width: parent.width
            spacing: 4
            Glass {
                width: parent.width; height: 40; radius: 20
                color: rm.containsMouse ? Theme.glassHover : Theme.glassFill
                TIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "wifi"; size: 16; opacity: 0.4 + 0.6 * row.modelData.q / 100 }
                Text {
                    x: 38; width: parent.width - 38 - 44
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: Theme.label; elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: 12; font.weight: row.modelData.cur ? Font.Bold : Font.Medium
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                    text: root.busy === row.modelData.name ? "…" : row.modelData.cur ? "✓" : row.modelData.sec !== "open" ? "🔒" : ""
                    color: row.modelData.cur ? Theme.accent : Theme.muted; font.pixelSize: 12
                }
                MouseArea {
                    id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.cur || root.busy) return;
                        if (row.modelData.sec === "open" || row.modelData.saved) root.connectTo(row.modelData.name, "");
                        else { root.joining = row.modelData.name; root.error = ""; pw.forceActiveFocus(); }
                    }
                }
            }
            Glass {
                visible: root.joining === row.modelData.name
                width: parent.width; height: 38; radius: 19
                TextInput {
                    id: pw
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 60
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password; color: Theme.label
                    font.family: Theme.font; font.pixelSize: 12
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    Keys.onReturnPressed: root.connectTo(row.modelData.name, text)
                    Keys.onEscapePressed: root.joining = ""
                    Text { visible: !parent.text; text: "Password"; color: Theme.muted; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    width: 50; height: 30; radius: 15; color: Theme.accent
                    Text { anchors.centerIn: parent; text: "Join"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.connectTo(row.modelData.name, pw.text) }
                }
            }
        }
    }
    Text {
        visible: root.error !== ""
        width: parent.width; wrapMode: Text.WordWrap
        text: root.error; color: "#FF6B6B"; font.family: Theme.font; font.pixelSize: 11
    }
}
