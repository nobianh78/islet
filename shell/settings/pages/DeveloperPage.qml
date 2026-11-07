import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Developer: SSH, Docker, file ẩn, danh tính Git, bộ lập trình.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool ssh: false
    property bool docker: false
    property bool hasDocker: false
    property bool hidden: false
    property string gitName: ""
    property string gitEmail: ""
    property string msg: ""
    onVisibleChanged: if (visible) st.running = true
    Process {
        id: st
        command: ["sh", "-c", 'systemctl is-active sshd; systemctl is-active docker; command -v docker >/dev/null && echo yes || echo no; gsettings get org.gtk.gtk4.Settings.FileChooser show-hidden 2>/dev/null || echo false; git config --global user.name; echo; git config --global user.email; echo']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                page.ssh = l[0] === "active"; page.docker = l[1] === "active"; page.hasDocker = l[2] === "yes";
                page.hidden = l[3] === "true"; page.gitName = l[4] || ""; page.gitEmail = l[6] || l[5] || "";
                nameIn.text = page.gitName; mailIn.text = page.gitEmail;
            }
        }
    }
    function svc(name, on) { Admin.run(["service", on ? "on" : "off", name], (ok, out) => { page.msg = ok ? "" : out; st.running = true; }); }

    SectionLabel { text: "Services" }
    Card {
        width: parent.width
        height: vCol.implicitHeight + 8
        Column {
            id: vCol
            y: 4; width: parent.width
            Row2 { title: "SSH server"; sub: page.ssh ? "On — this computer accepts SSH logins" : "Off"; checked: page.ssh; onToggled: page.svc("sshd", !page.ssh) }
            Row2 { divider: true; visible: page.hasDocker; title: "Docker"; sub: page.docker ? "Running" : "Stopped"; checked: page.docker; onToggled: page.svc("docker", !page.docker) }
        }
    }
    SectionLabel { text: "Files" }
    Card {
        width: parent.width; height: 58
        Row2 {
            title: "Show hidden files"; sub: "Dotfiles like .config and .git in Files and file pickers"; checked: page.hidden
            onToggled: { Quickshell.execDetached(["gsettings", "set", "org.gtk.gtk4.Settings.FileChooser", "show-hidden", String(!page.hidden)]); page.hidden = !page.hidden; }
        }
    }
    SectionLabel { text: "Git identity" }
    Card {
        width: parent.width; height: gCol.implicitHeight + 32
        Column {
            id: gCol
            x: 18; y: 16; width: parent.width - 36; spacing: 10
            Repeater {
                model: [["Name", "Your Name"], ["Email", "you@example.com"]]
                Rectangle {
                    required property var modelData
                    required property int index
                    width: gCol.width; height: 36; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.07)
                    Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[0]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                }
            }
        }
        TextInput { id: nameIn; x: 90; y: 16; width: parent.width - 120; height: 36; verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        TextInput { id: mailIn; x: 90; y: 62; width: parent.width - 120; height: 36; verticalAlignment: TextInput.AlignVCenter; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
    }
    Row {
        spacing: 10
        Pill {
            label: "Save Git identity"; primary: true
            onClicked: { Quickshell.execDetached(["git", "config", "--global", "user.name", nameIn.text]); Quickshell.execDetached(["git", "config", "--global", "user.email", mailIn.text]); page.msg = "Saved — new commits use this name and email"; }
        }
        Pill { label: "Install a dev stack…"; onClicked: Ui.openStore() }
        Pill { label: "Open Projects"; onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$HOME/Projects"; nautilus "$HOME/Projects"']) }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
}
