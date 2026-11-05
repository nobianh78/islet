import QtQuick
import "../common"
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../services"

// Tab Ứng dụng: cửa sổ đang mở, CPU / RAM gộp cả tiến trình con, nút Chuyển tới / Đóng.
Item {
    id: root

    readonly property var wins: {
        SysMon.last;   // cập nhật mỗi giây cùng số liệu
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.pid) continue;
            const u = SysMon.treeUsage(o.pid);
            out.push({ t: t, cls: o.class || "", title: o.title || "", pid: o.pid, cpu: u.cpu, rss: u.rss, n: u.count,
                       minimized: Windows.isMinimized(t) });
        }
        out.sort((a, b) => b.cpu - a.cpu || b.rss - a.rss);
        return out;
    }

    function iconFor(cls) {
        const e = DesktopEntries.byId(cls) ?? DesktopEntries.byId(cls.toLowerCase());
        return Quickshell.iconPath(e?.icon ?? cls, true) || Quickshell.iconPath(cls.toLowerCase(), true)
            || Quickshell.iconPath("application-x-executable", true);
    }

    // vị trí cột (chừa 190px bên phải cho nút Chuyển tới / Đóng)
    readonly property real colCpu: width - 360
    readonly property real colMem: width - 290

    // tiêu đề cột
    Item {
        id: header
        width: parent.width
        height: 22
        Text { x: 14; text: "Apps"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        Text { x: root.colCpu; width: 70; horizontalAlignment: Text.AlignRight; text: "CPU"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        Text { x: root.colMem; width: 90; horizontalAlignment: Text.AlignRight; text: "Memory"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
    }

    ListView {
        y: header.height + 4
        width: parent.width
        height: parent.height - y
        clip: true
        spacing: 6
        model: root.wins
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            width: ListView.view.width
            height: 56
            radius: 16
            color: rm.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: rm }

            AppIcon {
                id: ic
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                name: Theme.appKey(row.modelData.cls)
                source: root.iconFor(row.modelData.cls)
            }
            Column {
                anchors.left: ic.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: root.colCpu - x - 10
                Row {
                    spacing: 8
                    Text {
                        text: Windows.nameOf(row.modelData.t)
                        color: "#FFFFFF"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: row.modelData.minimized
                        anchors.verticalCenter: parent.verticalCenter
                        width: mt.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Qt.rgba(1, 0.71, 0.28, 0.18)
                        Text { id: mt; anchors.centerIn: parent; text: "minimized"; color: "#FFB547"; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
                    }
                }
                Text {
                    width: parent.width
                    text: row.modelData.title + "  ·  " + row.modelData.n + " processes"
                    color: "#8E8E93"
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }

            Text {
                x: root.colCpu
                width: 70
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: row.modelData.cpu.toFixed(1) + "%"
                color: row.modelData.cpu > 50 ? "#FF6B97" : "#FFFFFF"
                font.family: Theme.font
                font.pixelSize: 13
                font.features: ({ "tnum": 1 })
            }
            Text {
                x: root.colMem
                width: 90
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: SysMon.bytes(row.modelData.rss)
                color: "#FFFFFF"
                font.family: Theme.font
                font.pixelSize: 13
                font.features: ({ "tnum": 1 })
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                PillButton {
                    label: row.modelData.minimized ? "Reopen" : "Switch to"
                    onClicked: {
                        if (row.modelData.minimized) Windows.restore(row.modelData.t);
                        else Windows.focusWin(row.modelData.t);
                        Ui.taskOpen = false;
                    }
                }
                PillButton { label: "Close"; danger: true; onClicked: Windows.closeWin(row.modelData.t) }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.wins.length === 0
            text: "No apps are open"
            color: "#8E8E93"
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
