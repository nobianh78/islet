import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Updates (phần thêm): tự cập nhật ban đêm, chọn máy chủ tải nhanh nhất.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool auto: false
    property string msg: ""
    property bool ranking: false
    onVisibleChanged: if (visible) st.running = true
    Process { id: st; command: ["systemctl", "is-enabled", "islet-autoupdate.timer"]; stdout: StdioCollector { onStreamFinished: page.auto = text.trim() === "enabled" } }
    SectionLabel { text: "Options" }
    Card {
        width: parent.width; height: 58
        Row2 { title: "Update automatically at night"; sub: "Around 3:00 while plugged in — a snapshot is taken first on Btrfs"; checked: page.auto; onToggled: Admin.run(["autoupdate", page.auto ? "off" : "on"], (ok, out) => { page.msg = ok ? "" : out; st.running = true; }) }
    }
    Card {
        width: parent.width; height: 64
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Download servers"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: page.ranking ? "Testing servers near you… (about a minute)" : "Pick the fastest mirrors for downloads and updates"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
        }
        Pill {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            label: page.ranking ? "Testing…" : "Find fastest"
            onClicked: if (!page.ranking) { page.ranking = true; Admin.run(["mirrors"], (ok, out) => { page.ranking = false; page.msg = ok ? "Fastest servers:\n" + out.replace(/Server = /g, "").replace(/\/\$repo.*$/gm, "") : out; }); }
        }
    }
    Text { visible: page.msg !== ""; width: parent.width; wrapMode: Text.Wrap; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
}
