import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Wallpaper (phần thêm): hình nền riêng ban đêm, tải ảnh đẹp từ mạng.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool fetching: false
    property string msg: ""
    signal fetched()
    SectionLabel { text: "At night" }
    Card {
        width: parent.width; height: nCol.implicitHeight + 28
        Column {
            id: nCol
            x: 18; y: 14; width: parent.width - 36; spacing: 10
            Text { text: "Switch to a darker wallpaper from " + Prefs.nightFrom + " to " + Prefs.nightTo + " (same hours as Night Light)"; width: parent.width; wrapMode: Text.Wrap; color: Theme.labelSoft; font.family: Theme.font; font.pixelSize: 12 }
            Flow {
                width: parent.width; spacing: 8
                Chip { label: "Off"; on: Prefs.wallNight === ""; onClicked: Prefs.set("wallNight", "") }
                Repeater { model: Prefs.presets; Chip { required property var modelData; label: modelData.label; on: Prefs.wallNight === "preset:" + modelData.id; onClicked: Prefs.set("wallNight", "preset:" + modelData.id) } }
            }
        }
    }
    SectionLabel { text: "New photo" }
    Card {
        width: parent.width; height: 64
        Column {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Get a random landscape photo"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: "From picsum.photos · saved to Pictures/Wallpapers"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
        }
        Pill {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            label: page.fetching ? "Downloading…" : "Get photo"; primary: true
            onClicked: if (!page.fetching) {
                page.fetching = true;
                const f = Quickshell.env("HOME") + "/Pictures/Wallpapers/islet-photo-" + Date.now() + ".jpg";
                dl.file = f;
                dl.command = ["sh", "-c", 'mkdir -p "$(dirname "$0")" && curl -fsSL --max-time 30 -o "$0" "https://picsum.photos/2560/1600" && [ -s "$0" ]', f];
                dl.running = true;
            }
        }
    }
    Process {
        id: dl
        property string file: ""
        onExited: code => { page.fetching = false; if (code === 0) { Prefs.set("wallpaper", file); page.msg = "New wallpaper set"; page.fetched(); } else page.msg = "Couldn't download a photo (offline?)"; }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
}
