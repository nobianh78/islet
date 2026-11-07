import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Accessibility: kính lúp, chữ to, tương phản cao, giảm chuyển động, con trỏ to, trình đọc màn hình.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool orca: false
    onVisibleChanged: if (visible) oc.running = true
    Process { id: oc; command: ["pgrep", "-x", "orca"]; onExited: code => page.orca = code === 0 }

    SectionLabel { text: "Seeing" }
    Slider {
        width: parent.width
        title: "Screen zoom (follows the pointer)"
        label: v => Math.round((1 + v * 3) * 100) + "%"
        value: (Prefs.zoom - 1) / 3
        fill: Theme.accent
        onMoved: v => Prefs.set("zoom", Math.round((1 + v * 3) * 20) / 20)
    }
    Card {
        width: parent.width; height: 70
        Text { x: 18; y: 14; text: "Text size in apps"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        Row {
            x: 18; y: 36; spacing: 6
            Repeater {
                model: [[1, "Default"], [1.15, "Large"], [1.3, "Larger"], [1.5, "Largest"]]
                Chip { required property var modelData; label: modelData[1]; on: Math.abs(Prefs.textScale - modelData[0]) < 0.01; onClicked: Prefs.set("textScale", modelData[0]) }
            }
        }
    }
    Card {
        width: parent.width; height: 70
        Text { x: 18; y: 14; text: "Pointer size"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
        Row {
            x: 18; y: 36; spacing: 6
            Repeater {
                model: [[24, "Default"], [32, "Large"], [48, "Larger"], [64, "Largest"]]
                Chip { required property var modelData; label: modelData[1]; on: Prefs.cursorSize === modelData[0]; onClicked: Prefs.set("cursorSize", modelData[0]) }
            }
        }
    }
    Card {
        width: parent.width
        height: aCol.implicitHeight + 8
        Column {
            id: aCol
            y: 4; width: parent.width
            Row2 { title: "High contrast"; sub: "Stronger edges and colors in apps"; checked: Prefs.highContrast; onToggled: Prefs.set("highContrast", !Prefs.highContrast) }
            Row2 { divider: true; title: "Reduce motion"; sub: "Turns off window and desktop animations"; checked: Prefs.reduceMotion; onToggled: Prefs.set("reduceMotion", !Prefs.reduceMotion) }
        }
    }
    SectionLabel { text: "Hearing & reading" }
    Card {
        width: parent.width; height: 58
        Row2 {
            title: "Screen reader (Orca)"
            sub: page.orca ? "On — reads out what is on screen" : "Off"
            checked: page.orca
            onToggled: {
                if (page.orca) Quickshell.execDetached(["pkill", "-x", "orca"]);
                else Quickshell.execDetached(["sh", "-c", "gsettings set org.gnome.desktop.interface toolkit-accessibility true; setsid -f orca"]);
                later.restart();
            }
        }
    }
    Timer { id: later; interval: 1500; onTriggered: oc.running = true }
    Hint { text: "When zoomed in, the enlarged view follows your pointer around the screen." }
}
