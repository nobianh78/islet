import QtQuick
import Quickshell.Hyprland
import "../theme"

// Chấm workspace: chấm đang mở kéo dài thành viên thuốc, có lò xo.
Row {
    id: root
    spacing: 6

    readonly property int count: Prefs.wsCount
    readonly property int current: Hyprland.focusedWorkspace?.id ?? 1

    function occupied(id) {
        const ws = Hyprland.workspaces.values;
        for (let i = 0; i < ws.length; i++)
            if (ws[i].id === id && (ws[i].toplevels?.values?.length ?? 1) > 0) return true;
        return false;
    }

    Repeater {
        model: root.count

        Rectangle {
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: root.current === wsId

            anchors.verticalCenter: parent.verticalCenter
            width: active ? 22 : 7
            height: 7
            radius: 3.5
            color: active ? Theme.violet
                : root.occupied(wsId) ? Qt.rgba(1, 1, 1, 0.75)
                : Qt.rgba(1, 1, 1, 0.28)

            Behavior on width { SpringAnimation { spring: 4.5; damping: 0.3 } }
            Behavior on color { ColorAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.wsId + " })")
            }
        }
    }
}
