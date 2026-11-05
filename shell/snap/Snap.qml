import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Xếp cửa sổ kiểu Windows 11 (phần hiển thị; logic kéo-thả nằm trong hypr/hyprland.lua):
//   · khung xem trước khi kéo cửa sổ ra mép (islet-ipc snap show x y w h / hide)
//     — vẽ ở lớp Bottom: dưới cửa sổ, trên hình nền, giống Windows
//   · lưới bố cục (Super+Z hoặc islet-ipc snap picker): bấm một ô → hyprctl eval islet_snap(...)
Scope {
    id: root

    property rect target: Qt.rect(0, 0, 0, 0)
    property bool showing: false
    property bool picker: false
    property string pickAddr: ""

    IpcHandler {
        target: "snap"
        function show(x: int, y: int, w: int, h: int): void { root.target = Qt.rect(x, y, w, h); root.showing = true; }
        function hide(): void { root.showing = false; }
        function picker(): void {
            root.pickAddr = Hyprland.activeToplevel?.lastIpcObject?.address ?? "";
            root.picker = root.pickAddr !== "" && !root.picker;
        }
    }

    function snap(zone) {
        Quickshell.execDetached(["hyprctl", "eval", "islet_snap('" + zone + "', '" + pickAddr + "')"]);
        picker = false;
    }

    // ---------------- khung xem trước ----------------
    PanelWindow {
        id: prev
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        focusable: false
        WlrLayershell.namespace: "islet-snap"
        WlrLayershell.layer: WlrLayer.Bottom
        visible: root.showing || box.opacity > 0.01
        mask: Region {}

        Rectangle {
            id: box
            // trượt + nở tới vùng đích bằng lò xo
            x: root.target.x - (prev.screen?.x ?? 0)
            y: root.target.y - (prev.screen?.y ?? 0)
            width: root.target.width
            height: root.target.height
            Behavior on x { enabled: box.opacity > 0.05; SpringAnimation { spring: 5; damping: 0.36; epsilon: 0.3 } }
            Behavior on y { enabled: box.opacity > 0.05; SpringAnimation { spring: 5; damping: 0.36; epsilon: 0.3 } }
            Behavior on width { enabled: box.opacity > 0.05; SpringAnimation { spring: 5; damping: 0.36; epsilon: 0.3 } }
            Behavior on height { enabled: box.opacity > 0.05; SpringAnimation { spring: 5; damping: 0.36; epsilon: 0.3 } }
            radius: 18
            color: Theme.tint(0.18)
            border.width: 2
            border.color: Theme.tint(0.7)
            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.003 } }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }
    }

    // ---------------- lưới bố cục (Super+Z) ----------------
    PanelWindow {
        id: pick
        implicitWidth: 560
        implicitHeight: 124
        anchors.top: true
        margins.top: 56
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "islet-snappicker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.picker ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        visible: root.picker || card.opacity > 0.01
        mask: Region { item: card }

        HyprlandFocusGrab {
            windows: [pick]
            active: root.picker
            onCleared: root.picker = false
        }

        // mỗi bố cục: danh sách ô [vùng, x, y, w, h] theo tỉ lệ 0..1
        readonly property var layouts: [
            [["left", 0, 0, 0.5, 1], ["right", 0.5, 0, 0.5, 1]],
            [["l23", 0, 0, 0.66, 1], ["r3", 0.66, 0, 0.34, 1]],
            [["l3", 0, 0, 0.333, 1], ["c3", 0.333, 0, 0.334, 1], ["r3", 0.667, 0, 0.333, 1]],
            [["tl", 0, 0, 0.5, 0.5], ["tr", 0.5, 0, 0.5, 0.5], ["bl", 0, 0.5, 0.5, 0.5], ["br", 0.5, 0.5, 0.5, 0.5]],
            [["left", 0, 0, 0.5, 1], ["tr", 0.5, 0, 0.5, 0.5], ["br", 0.5, 0.5, 0.5, 0.5]],
            [["top", 0, 0, 1, 0.5], ["bottom", 0, 0.5, 1, 0.5]]
        ]

        Glass {
            id: card
            anchors.fill: parent
            radius: 24
            color: Qt.rgba(0.06, 0.06, 0.1, 0.7)
            opacity: root.picker ? 1 : 0
            scale: root.picker ? 1 : 0.9
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.003 } }
            focus: root.picker
            Keys.onEscapePressed: root.picker = false

            Text {
                x: 18; y: 14
                text: "Snap layouts"
                color: "#FFFFFF"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 15
                text: "Super + ← → ↑ ↓ · drag to an edge"
                color: "#8E8E93"
                font.family: Theme.font
                font.pixelSize: 11
            }

            Row {
                x: 18; y: 44
                spacing: 12
                Repeater {
                    model: pick.layouts
                    // một bố cục = một màn hình nhỏ chia ô
                    Item {
                        id: lay
                        required property var modelData
                        width: 76; height: 64
                        Rectangle {
                            id: screenBox
                            anchors.centerIn: parent
                            width: 76; height: 50
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            Repeater {
                                model: lay.modelData
                                Rectangle {
                                    required property var modelData
                                    readonly property real g: 2
                                    x: 3 + modelData[1] * (screenBox.width - 6) + g / 2
                                    y: 3 + modelData[2] * (screenBox.height - 6) + g / 2
                                    width: modelData[3] * (screenBox.width - 6) - g
                                    height: modelData[4] * (screenBox.height - 6) - g
                                    radius: 5
                                    color: zm.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
                                    Behavior on color { ColorAnimation { duration: 110 } }
                                    scale: zm.pressed ? 0.92 : 1
                                    MouseArea {
                                        id: zm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.snap(parent.modelData[0])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
