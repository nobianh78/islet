import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Users & Account (phần thêm): ảnh đại diện, tên hiển thị, thêm người dùng.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property string fullName: ""
    property var pictures: []
    property string msg: ""
    readonly property string face: Quickshell.env("HOME") + "/.face"
    property int faceV: 0
    onVisibleChanged: if (visible) { pics.running = true; nameIn.text = fullName; }
    Process {
        id: pics
        command: ["sh", "-c", 'for d in "$HOME/Pictures" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \\); done | head -12']
        stdout: StdioCollector { onStreamFinished: page.pictures = text.split("\n").filter(x => x) }
    }
    property bool hasFace: false
    Process { id: faceCheck; running: true; command: ["test", "-f", page.face]; onExited: code => page.hasFace = code === 0 }
    Process { id: setFace; onExited: { page.faceV++; page.msg = "Picture updated"; faceCheck.running = true; } }

    SectionLabel { text: "Picture" }
    Card {
        width: parent.width; height: 124
        Rounded {
            x: 18; anchors.verticalCenter: parent.verticalCenter; width: 72; height: 72; radius: 36
            Image { anchors.fill: parent; source: page.hasFace ? "file://" + page.face + "?" + page.faceV : ""; fillMode: Image.PreserveAspectCrop; cache: false; visible: status === Image.Ready }
            Image { anchors.fill: parent; anchors.margins: 6; source: Qt.resolvedUrl("../../assets/brand/cat.svg"); visible: parent.children[0].status !== Image.Ready }
        }
        Flickable {
            x: 108; y: 16; width: parent.width - 126; height: 92
            contentWidth: picRow.implicitWidth; clip: true; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: picRow
                spacing: 8
                Rectangle {
                    width: 56; height: 56; radius: 28; color: Qt.rgba(1, 1, 1, 0.08); anchors.verticalCenter: parent.verticalCenter
                    Image { anchors.fill: parent; anchors.margins: 6; source: Qt.resolvedUrl("../../assets/brand/cat.svg") }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { setFace.command = ["rm", "-f", page.face]; setFace.running = true; } }
                }
                Repeater {
                    model: page.pictures
                    Rounded {
                        required property string modelData
                        width: 56; height: 56; radius: 28; anchors.verticalCenter: parent.verticalCenter
                        Image { anchors.fill: parent; source: "file://" + parent.modelData; sourceSize: Qt.size(112, 112); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { setFace.command = ["sh", "-c", 'command -v magick >/dev/null && magick "$0" -resize 256x256^ -gravity center -extent 256x256 "$1" || cp "$0" "$1"', parent.modelData, page.face]; setFace.running = true; } }
                    }
                }
            }
        }
    }
    SectionLabel { text: "Name" }
    Card {
        width: parent.width; height: 64
        Row {
            x: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Field { id: nameIn; width: 260; hint: "Your full name" }
            Pill { label: "Save"; primary: true; onClicked: Admin.run(["user", "fullname", Quickshell.env("USER"), Qt.btoa(unescape(encodeURIComponent(nameIn.text.trim())))], (ok, out) => page.msg = ok ? "Name saved" : out) }
        }
    }
    SectionLabel { text: "Add a user" }
    Card {
        width: parent.width; height: 112
        Row {
            x: 18; y: 16; spacing: 8
            Field { id: nuName; width: 150; hint: "username" }
            Field { id: nuFull; width: 180; hint: "Full name" }
        }
        Row {
            x: 18; y: 62; spacing: 8
            PwField { id: nuPw; width: 200; hint: "Password" }
            Pill {
                label: "Add user"; primary: true
                onClicked: {
                    if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(nuName.text)) { page.msg = "Username: lowercase letters, numbers, - and _"; return; }
                    if (nuPw.text.length < 4) { page.msg = "Password needs at least 4 characters"; return; }
                    Admin.run(["user", "add", nuName.text, Qt.btoa(unescape(encodeURIComponent(nuFull.text)))], (ok, out) => { page.msg = ok ? "Added " + nuName.text + " — they can sign in from a text console (Ctrl+Alt+F2); switching users from the lock screen is not available yet" : out; if (ok) { nuName.text = ""; nuFull.text = ""; nuPw.text = ""; } }, nuPw.text);
                }
            }
        }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
}
