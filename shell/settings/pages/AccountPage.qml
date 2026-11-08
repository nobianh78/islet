import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import ".."
// Cài đặt › Account — MỘT chỗ duy nhất cho mọi thứ về tài khoản:
//   ảnh + tên (bấm vào để sửa) · đăng nhập & mật khẩu · những người khác dùng máy này.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12

    property string fullName: ""
    signal renamed()                       // báo Settings đọc lại tên (thẻ tài khoản ở cột trái)
    readonly property string userName: Quickshell.env("USER") || ""
    readonly property string face: Quickshell.env("HOME") + "/.face"

    property bool editingName: false
    property bool pickingPicture: false
    property bool changingPw: false
    property bool addingUser: false
    property string msg: ""
    property bool msgOk: true
    function say(t, ok) { msg = t; msgOk = ok !== false; msgClear.restart(); }
    Timer { id: msgClear; interval: 6000; onTriggered: page.msg = "" }

    onVisibleChanged: if (visible) { faceCheck.running = true; pics.running = true; others.running = true; }

    // ---------- ảnh đại diện ----------
    property bool hasFace: false
    property int faceV: 0
    property var pictures: []
    Process { id: faceCheck; command: ["test", "-f", page.face]; onExited: code => page.hasFace = code === 0 }
    Process {
        id: pics
        command: ["sh", "-c", 'for d in "$HOME/Pictures" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots" /usr/share/islet/wallpapers; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \\); done | head -16']
        stdout: StdioCollector { onStreamFinished: page.pictures = text.split("\n").filter(x => x) }
    }
    Process { id: setFace; onExited: { page.faceV++; faceCheck.running = true; page.pickingPicture = false; page.say("Picture updated"); } }
    function pickFace(path) {
        if (!path) setFace.command = ["rm", "-f", face];
        else setFace.command = ["sh", "-c", 'command -v magick >/dev/null && magick "$0" -resize 256x256^ -gravity center -extent 256x256 "$1" || cp "$0" "$1"', path, face];
        setFace.running = true;
    }

    // ---------- người dùng khác ----------
    property var people: []
    Process {
        id: others
        command: ["sh", "-c", 'getent passwd | awk -F: -v me="$USER" \'$3>=1000 && $3<60000 && $1!=me {split($5,a,","); print $1 "\\t" a[1]}\'']
        stdout: StdioCollector { onStreamFinished: page.people = text.split("\n").filter(x => x).map(l => { const p = l.split("\t"); return { user: p[0], name: p[1] || p[0] }; }) }
    }

    // ---------- đổi mật khẩu ----------
    property bool pwBusy: false
    function changePassword() {
        if (newPw.text.length < 4) { say("The new password needs at least 4 characters", false); return; }
        if (newPw.text !== newPw2.text) { say("The new passwords don't match", false); return; }
        pwBusy = true;
        // xác minh mật khẩu hiện tại một lần qua PAM (tránh khoá tài khoản vì sudo sai nhiều lần)
        Auth.verify(oldPw.text, ok => {
            if (!ok) { page.pwBusy = false; page.say("Current password is wrong", false); return; }
            chpw.input = oldPw.text + "\n" + page.userName + ":" + newPw.text + "\n";
            chpw.running = true;
        });
    }
    Process {
        id: chpw
        property string input: ""
        command: ["sudo", "-S", "-p", "", "chpasswd"]
        stdinEnabled: true
        onStarted: { write(input); input = ""; stdinEnabled = false; }
        onExited: code => {
            stdinEnabled = true;
            page.pwBusy = false;
            if (code === 0) { oldPw.text = ""; newPw.text = ""; newPw2.text = ""; page.changingPw = false; page.say("Password changed"); }
            else page.say("Couldn't change the password", false);
        }
    }

    function b64(s) { return Qt.btoa(unescape(encodeURIComponent(s))); }

    // ================= thẻ tài khoản =================
    Card {
        width: parent.width
        height: 120
        // ảnh: bấm để đổi
        Item {
            id: avatar
            x: 22; anchors.verticalCenter: parent.verticalCenter
            width: 84; height: 84
            Rectangle { anchors.fill: parent; radius: 42; color: Theme.fg(0.07) }
            Image { anchors.fill: parent; anchors.margins: 10; visible: faceImg.status !== Image.Ready; source: Qt.resolvedUrl("../../assets/brand/cat.svg"); sourceSize: Qt.size(128, 128) }
            Rounded {
                anchors.fill: parent; radius: 42
                Image { id: faceImg; anchors.fill: parent; source: page.hasFace ? "file://" + page.face + "?" + page.faceV : ""; sourceSize: Qt.size(168, 168); fillMode: Image.PreserveAspectCrop; cache: false }
            }
            Rectangle {
                anchors.fill: parent; radius: 42
                color: Theme.surface(0.5)
                opacity: am.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Text { anchors.centerIn: parent; text: "Edit"; color: Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
            }
            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.pickingPicture = !page.pickingPicture }
        }
        // tên: bấm bút chì để sửa
        Column {
            x: 128; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 150
            spacing: 4
            Row {
                visible: !page.editingName
                spacing: 8
                Text { text: page.fullName || page.userName; color: Theme.label; font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Bold }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    color: em.containsMouse ? Theme.fg(0.14) : "transparent"
                    TIcon { anchors.centerIn: parent; name: "edit"; size: 13; opacity: 0.8 }
                    MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { nameIn.text = page.fullName; page.editingName = true; } }
                }
            }
            Row {
                visible: page.editingName
                spacing: 8
                Field { id: nameIn; width: 240; hint: "Your full name"; onAccepted: saveName.clicked() }
                Pill {
                    id: saveName
                    label: "Save"; primary: true
                    onClicked: {
                        const n = nameIn.text.trim();
                        if (!n) return;
                        Admin.run(["user", "fullname", page.userName, page.b64(n)], (ok, out) => {
                            if (ok) { page.editingName = false; page.renamed(); page.say("Name saved"); } else page.say(out, false);
                        });
                    }
                }
                Pill { label: "Cancel"; onClicked: page.editingName = false }
            }
            Text { text: page.userName + "  ·  Administrator"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
        }
    }

    // chọn ảnh (hiện khi bấm vào ảnh)
    Card {
        visible: page.pickingPicture
        width: parent.width
        height: 96
        Flickable {
            x: 16; y: 14; width: parent.width - 32; height: 68
            contentWidth: picRow.implicitWidth; clip: true; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: picRow
                spacing: 10
                Rectangle {
                    width: 64; height: 64; radius: 32; color: Theme.fg(0.08)
                    border.width: !page.hasFace ? 2 : 0; border.color: Theme.accent
                    Image { anchors.fill: parent; anchors.margins: 8; source: Qt.resolvedUrl("../../assets/brand/cat.svg"); sourceSize: Qt.size(96, 96) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.pickFace("") }
                }
                Repeater {
                    model: page.pictures
                    Rounded {
                        id: pd
                        required property string modelData
                        width: 64; height: 64; radius: 32
                        Image { anchors.fill: parent; source: "file://" + pd.modelData; sourceSize: Qt.size(128, 128); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.pickFace(pd.modelData) }
                    }
                }
            }
        }
    }
    Hint { visible: page.pickingPicture; text: "Pictures come from your Pictures folder. The picture also shows on the lock screen." }

    // ================= đăng nhập & mật khẩu =================
    SectionLabel { text: "Sign-in & password" }
    Card {
        width: parent.width
        height: signCol.implicitHeight
        Column {
            id: signCol
            width: parent.width
            Row2 { title: "Ask for my password when the computer starts"; sub: "Off = go straight to the desktop after turning on"; checked: Prefs.lockOnBoot; onToggled: Prefs.set("lockOnBoot", !Prefs.lockOnBoot) }
            Item {
                width: parent.width; height: 58
                Rectangle { x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                Column {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Password"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                    Text { text: "Used to unlock the screen and change system settings"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                }
                Pill { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; label: page.changingPw ? "Cancel" : "Change…"; onClicked: page.changingPw = !page.changingPw }
            }
            Column {
                visible: page.changingPw
                x: 18; width: parent.width - 36
                spacing: 10
                bottomPadding: 16
                PwField { id: oldPw; width: parent.width; hint: "Current password" }
                PwField { id: newPw; width: parent.width; hint: "New password" }
                PwField { id: newPw2; width: parent.width; hint: "Confirm new password"; onAccepted: page.changePassword() }
                Pill { label: page.pwBusy ? "Changing…" : "Change password"; primary: true; onClicked: if (!page.pwBusy) page.changePassword() }
            }
        }
    }

    // ================= người khác =================
    SectionLabel { text: "Other people on this computer" }
    Card {
        width: parent.width
        height: peopleCol.implicitHeight
        Column {
            id: peopleCol
            width: parent.width
            Repeater {
                model: page.people
                Item {
                    required property var modelData
                    required property int index
                    width: peopleCol.width; height: 56
                    Rectangle { visible: parent.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    Rectangle {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 34; radius: 17; color: Theme.fg(0.08)
                        Text { anchors.centerIn: parent; text: (parent.parent.modelData.name || "?").charAt(0).toUpperCase(); color: Theme.label; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                    }
                    Column {
                        x: 64; anchors.verticalCenter: parent.verticalCenter
                        Text { text: parent.parent.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: parent.parent.modelData.user; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }
            }
            Item {
                width: parent.width; height: 58
                Rectangle { visible: page.people.length > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                Text {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    text: page.people.length ? "Add another person" : "Only you use this computer"
                    color: page.people.length ? Theme.label : Theme.subtle; font.family: Theme.font; font.pixelSize: 13
                }
                Pill { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; label: page.addingUser ? "Cancel" : "Add person…"; onClicked: page.addingUser = !page.addingUser }
            }
            Column {
                visible: page.addingUser
                x: 18; width: parent.width - 36
                spacing: 10
                bottomPadding: 16
                Row {
                    spacing: 10
                    Field { id: nuFull; width: (peopleCol.width - 46) / 2; hint: "Full name" }
                    Field { id: nuName; width: (peopleCol.width - 46) / 2; hint: "username (lowercase)" }
                }
                PwField { id: nuPw; width: parent.width; hint: "Their password" }
                Pill {
                    label: "Add person"; primary: true
                    onClicked: {
                        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(nuName.text)) { page.say("Username: lowercase letters, numbers, - and _", false); return; }
                        if (nuPw.text.length < 4) { page.say("The password needs at least 4 characters", false); return; }
                        Admin.run(["user", "add", nuName.text, page.b64(nuFull.text)], (ok, out) => {
                            if (ok) { page.say("Added " + (nuFull.text || nuName.text)); nuName.text = ""; nuFull.text = ""; nuPw.text = ""; page.addingUser = false; others.running = true; }
                            else page.say(out, false);
                        }, nuPw.text);
                    }
                }
            }
        }
    }
    Hint { text: "Other people sign in from a text console for now (Ctrl+Alt+F2). Switching users on the lock screen is coming later." }

    Text { visible: page.msg !== ""; text: page.msg; color: page.msgOk ? "#34C77B" : "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12 }
}
