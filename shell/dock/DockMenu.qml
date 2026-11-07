import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"

// Menu chuột phải trên dock (kiểu Ubuntu):
//   tên app · các cửa sổ đang mở · Cửa sổ mới · hành động riêng của app (.desktop)
//   · Ghim / Bỏ ghim khỏi dock · Đóng N cửa sổ
PanelWindow {
    id: win

    property var dock: null
    property var app: null
    property real anchorX: 0
    property bool open: false

    anchors { bottom: true; left: true }
    margins {
        bottom: 84
        left: Math.max(8, Math.min((screen?.width ?? 1920) - implicitWidth - 8, anchorX - implicitWidth / 2))
    }
    implicitWidth: 272
    implicitHeight: col.implicitHeight + 16 + 10
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-dockmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    function openFor(a, x) {
        app = a;
        anchorX = x;
        open = true;
        panel.forceActiveFocus();
    }
    function close() { open = false; }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: win.close()
    }

    readonly property bool isApp: app && !app.launcher && !app.system
    readonly property var windows: isApp && dock ? dock.windowsOf(app.ids) : []
    // hành động riêng của app; bỏ "New Window" vì đã có "Cửa sổ mới"
    readonly property var actions: isApp ? (app.entry?.actions ?? []).filter(x => !/^new[- ]?window$/i.test(x.id) && !/^new window$/i.test(x.name)) : []
    readonly property var viNames: ({
        "New Private Window": "New Private Window",
        "Open Profile Manager": "Manage Profiles",
        "New Incognito Window": "New Incognito Window",
        "New Tab": "New Tab",
        "Open a New Window": "New Window",
        "Preferences": "Settings",
        "Settings": "Settings"
    })

    function run(fn) { fn(); close(); }

    Glass {
        id: panel
        width: parent.width
        height: col.implicitHeight + 16
        radius: 20
        color: Qt.rgba(0.06, 0.06, 0.1, 0.78)

        transformOrigin: Item.Bottom
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.85
        Behavior on opacity { NumberAnimation { duration: win.open ? 150 : 110; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.003 } }

        Keys.onEscapePressed: win.close()

        Column {
            id: col
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 2

            // ---- tên app ----
            Row {
                leftPadding: 8
                topPadding: 4
                bottomPadding: 6
                spacing: 10
                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 26
                    name: win.app?.icon ?? ""
                    source: win.app?.iconUrl ?? ""
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.app?.label ?? ""
                    color: "#FFFFFF"
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }

            // ---- các cửa sổ đang mở ----
            Repeater {
                model: win.windows
                MenuRow {
                    required property var modelData
                    label: modelData.title || win.app.label
                    dot: modelData.activated ? "active" : Windows.minimizedOf(win.app.ids).some(h => h.wayland === modelData) ? "min" : "open"
                    onClicked: win.run(() => {
                        const hidden = Windows.minimizedOf(win.app.ids).find(h => h.wayland === modelData);
                        if (hidden) Windows.restore(hidden); else modelData.activate();
                    })
                }
            }
            Sep { visible: win.windows.length > 0 }

            // ---- mở / cửa sổ mới / hành động riêng ----
            MenuRow {
                visible: win.app?.launcher ?? false
                icon: "grid"
                label: "Open Apps"
                onClicked: win.run(() => Ui.toggleLauncher())
            }
            MenuRow {
                visible: win.app?.system ?? false
                icon: "sliders"
                label: "Open Control Center"
                onClicked: win.run(() => Ui.toggleControlCenter())
            }
            MenuRow {
                visible: win.isApp && !!win.app?.entry
                icon: "plus"
                label: win.windows.length > 0 ? "New Window" : "Open"
                onClicked: win.run(() => win.dock.newWindow(win.app))
            }
            Repeater {
                model: win.actions
                MenuRow {
                    required property var modelData
                    icon: "dot"
                    label: win.viNames[modelData.name] ?? modelData.name
                    onClicked: win.run(() => modelData.execute())
                }
            }

            Sep { visible: win.isApp }

            // ---- ghim / đóng ----
            MenuRow {
                visible: win.isApp
                icon: "pin"
                label: win.app?.pinned ? "Unpin from Dock" : "Pin to Dock"
                onClicked: win.run(() => win.app.pinned ? DockPins.unpinApp(win.app) : DockPins.pin(win.app.key))
            }
            MenuRow {
                visible: win.windows.length > 0
                icon: "close"
                danger: true
                label: win.windows.length > 1 ? "Close " + win.windows.length + " windows" : "Close"
                onClicked: win.run(() => { for (const w of win.windows) w.close(); })
            }
        }
    }

    component Sep: Rectangle {
        width: col.width
        height: 9
        color: "transparent"
        Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
    }

    component MenuRow: Rectangle {
        id: r
        property string label: ""
        property string icon: ""
        property string dot: ""          // active | open | min (dòng cửa sổ)
        property bool danger: false
        signal clicked()

        width: col.width
        height: visible ? 34 : 0
        radius: 11
        color: m.containsMouse ? (danger ? Qt.rgba(1, 0.37, 0.34, 0.9) : Qt.rgba(1, 1, 1, 0.10)) : "transparent"
        Behavior on color { ColorAnimation { duration: 110 } }

        // chấm trạng thái cửa sổ / icon
        Item {
            id: lead
            x: 10
            width: 18
            height: parent.height
            Rectangle {
                visible: r.dot !== ""
                anchors.centerIn: parent
                width: r.dot === "active" ? 8 : 7
                height: width
                radius: width / 2
                color: r.dot === "active" ? Theme.violet : "transparent"
                border.width: r.dot === "active" ? 0 : 1.5
                border.color: r.dot === "min" ? "#FFB547" : Qt.rgba(1, 1, 1, 0.6)
            }
            Icon {
                visible: r.dot === "" && r.icon !== ""
                anchors.centerIn: parent
                name: r.icon
                size: r.icon === "dot" ? 12 : 15
                color: r.danger && m.containsMouse ? "#FFFFFF" : r.danger ? "#FF8A8A" : "#D1D1D6"
            }
        }
        Text {
            anchors.left: lead.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: r.label
            elide: Text.ElideRight
            color: r.danger && !m.containsMouse ? "#FF8A8A" : "#FFFFFF"
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: r.dot !== "" ? Font.Normal : Font.Medium
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: r.clicked()
        }
    }
}
