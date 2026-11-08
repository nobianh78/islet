import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Ô Xem nhanh của Islet (khi máy không có GNOME Sushi): ảnh, văn bản / code, và thẻ thông tin cho
// những thứ khác. Space hoặc Esc để đóng, Enter để mở bằng app thật.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: QuickLook.open || panel.opacity > 0.01

    WlrLayershell.namespace: "islet-quicklook"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: QuickLook.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var info: QuickLook.info
    readonly property string kind: info.kind ?? ""
    readonly property bool isImage: kind === "image"
    readonly property bool isText: (kind === "document" || kind === "code" || kind === "other")
        && (info.mime ?? "").startsWith("text/") && (info.size ?? 0) < 2000000
    readonly property bool isDir: info.dir ?? false

    onVisibleChanged: if (visible) panel.forceActiveFocus()

    // nền mờ, bấm ra ngoài để đóng
    Rectangle {
        anchors.fill: parent
        color: Theme.surface(0.45)
        opacity: QuickLook.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        MouseArea { anchors.fill: parent; onClicked: QuickLook.close() }
    }

    Item {
        id: panel
        focus: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 900)
        height: Math.min(parent.height - 140, 640)
        opacity: QuickLook.open ? 1 : 0
        scale: QuickLook.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.002 } }

        Keys.onEscapePressed: QuickLook.close()
        Keys.onReturnPressed: QuickLook.openInApp()
        Keys.onPressed: e => { if (e.key === Qt.Key_Space) { QuickLook.close(); e.accepted = true; } }

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: Theme.surface(0.98)
            border.width: 1; border.color: Theme.fg(0.12)
        }

        // ---- thanh trên ----
        Item {
            id: head
            width: parent.width; height: 56
            Image {
                id: hicon
                x: 18; anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22; sourceSize: Qt.size(44, 44)
                source: Quickshell.iconPath(win.info.icon ?? "text-x-generic", true)
                asynchronous: true
            }
            Column {
                x: 50; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 50 - acts.width - 24
                Text {
                    width: parent.width; elide: Text.ElideMiddle
                    text: QuickLook.name
                    color: Theme.label; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                }
                Text {
                    text: (win.isDir ? "Folder" : QuickLook.human(win.info.size ?? 0))
                        + (win.info.mtime ? "  ·  " + Qt.formatDateTime(new Date((win.info.mtime ?? 0) * 1000), "d MMM yyyy HH:mm") : "")
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
                }
            }
            Row {
                id: acts
                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Btn { label: win.isDir ? "Open folder" : "Open"; primary: true; onClicked: QuickLook.openInApp() }
                Btn { label: "Close"; onClicked: QuickLook.close() }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.fg(0.07) }
        }

        // ---- nội dung ----
        Item {
            anchors.top: head.bottom
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 16
            clip: true

            // ảnh
            Image {
                anchors.fill: parent
                visible: win.isImage
                source: win.isImage && QuickLook.path ? "file://" + QuickLook.path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                sourceSize: Qt.size(1600, 1200)
            }

            // văn bản / code
            FileView {
                id: fv
                path: win.isText ? QuickLook.path : ""
                printErrors: false
            }
            Flickable {
                anchors.fill: parent
                visible: win.isText
                contentWidth: Math.max(width, txt.implicitWidth)
                contentHeight: txt.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Text {
                    id: txt
                    text: win.isText ? fv.text() : ""
                    color: Theme.labelSoft
                    font.family: Theme.mono
                    font.pixelSize: 12
                    textFormat: Text.PlainText
                    wrapMode: Text.NoWrap
                }
            }

            // thứ khác: icon lớn + cho biết mở bằng gì
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: !win.isImage && !win.isText
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 86; height: 86; sourceSize: Qt.size(172, 172)
                    source: Quickshell.iconPath(win.info.icon ?? "text-x-generic", true)
                    asynchronous: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.info.mime || "No preview"
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.parent.width - 60, 420)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: win.isDir ? "Press Enter to open it in Files."
                        : (win.info.handler === "none") ? "Nothing on this computer opens this kind of file yet — the Store can help."
                        : (win.info.handler === "terminal") ? "Its usual app runs in a terminal, so there's nothing to preview here."
                        : "Press Enter to open it."
                    color: Theme.faint; font.family: Theme.font; font.pixelSize: 11
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: -22; anchors.horizontalCenter: parent.horizontalCenter
            text: "Space or Esc to close  ·  Enter to open"
            color: Theme.fg(0.55); font.family: Theme.font; font.pixelSize: 11
        }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool primary: false
        signal clicked()
        width: bl.implicitWidth + 26
        height: 30
        radius: 15
        color: primary ? (bm.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
                       : (bm.containsMouse ? Theme.fg(0.16) : Theme.fg(0.08))
        Behavior on color { ColorAnimation { duration: 130 } }
        Text { id: bl; anchors.centerIn: parent; text: b.label; color: b.primary ? "#FFFFFF" : Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
