import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › About (phần thêm): đổi tên máy, sức khoẻ ổ đĩa, chép thông tin máy.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property var sys: ({})
    property string disk: ""
    property string health: ""
    property string msg: ""
    onVisibleChanged: if (visible) { rootDisk.running = true; nameIn.text = sys.host || ""; }
    Process {
        id: rootDisk
        command: ["sh", "-c", 'p=$(findmnt -no SOURCE / | sed "s/\\[.*//"); k=$(lsblk -no PKNAME "$p" 2>/dev/null | head -1); [ -n "$k" ] && echo "/dev/$k"']
        stdout: StdioCollector { onStreamFinished: page.disk = text.trim() }
    }
    Card {
        width: parent.width; height: 104
        Text { x: 18; y: 16; text: "Computer name"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
        Text { x: 18; y: 34; text: "How this computer appears on the network and to Bluetooth devices"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
        Row {
            x: 18; y: 58; spacing: 8
            Field { id: nameIn; width: 240; hint: "islet" }
            Pill { label: "Rename"; primary: true; onClicked: Admin.run(["hostname", nameIn.text.trim()], (ok, out) => page.msg = ok ? "Renamed to " + nameIn.text.trim() : out) }
        }
    }
    Card {
        visible: page.disk !== ""
        width: parent.width; height: 64
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Disk health · " + page.disk; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: page.health === "PASSED" ? "Healthy" : page.health === "FAILED" ? "The disk reports problems — back up your files now" : page.health === "UNKNOWN" ? "This disk does not report health" : "Not checked yet"; color: page.health === "FAILED" ? "#FF8A8A" : page.health === "PASSED" ? "#34C77B" : Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
        }
        Pill { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; label: "Check"; onClicked: Admin.run(["smart", page.disk], (ok, out) => page.health = ok ? out : "UNKNOWN") }
    }
    Row {
        spacing: 10
        Pill {
            label: "Copy system info"
            onClicked: {
                const s = page.sys;
                const txt = ["Islet · " + (s.os || ""), "Kernel " + (s.kernel || ""), "CPU " + (s.cpu || "") + " (" + (s.cores || "?") + " threads)", "RAM " + (s.ram || ""), "GPU " + (s.gpu || ""), "Disk " + (s.disk || ""), "Hyprland " + (s.hypr || "")].join("\n");
                Clipboard.use({ kind: "text", text: txt }, false);
                page.msg = "System info copied";
            }
        }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
}
