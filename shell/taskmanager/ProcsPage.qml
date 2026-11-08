import QtQuick
import "../theme"
import "../services"
import "../common"

// Tab Tiến trình: tìm theo tên / PID, sắp theo CPU hoặc RAM (bấm tiêu đề cột),
// "Kết thúc" gửi SIGTERM; nếu sau đó vẫn còn, nút thành "Buộc dừng" (SIGKILL).
Item {
    id: root

    property string sortBy: "cpu"     // cpu | mem
    property string query: ""
    property var termSent: ({})        // pid → thời điểm gửi SIGTERM

    readonly property var rows: {
        const q = query.trim().toLowerCase();
        let l = SysMon.procs.filter(p => p[4] > 0 || p[3] > 0);   // bỏ luồng nhân (RSS = 0)
        if (q) l = l.filter(p => p[2].toLowerCase().includes(q) || String(p[0]).startsWith(q));
        l = l.slice().sort(sortBy === "cpu" ? ((a, b) => b[3] - a[3] || b[4] - a[4]) : ((a, b) => b[4] - a[4]));
        return l.slice(0, 150);
    }

    // ---------------- thanh trên: tìm + đếm ----------------
    Item {
        id: bar
        width: parent.width
        height: 36

        Rectangle {
            width: 280
            height: 34
            radius: 17
            color: Theme.fg(search.activeFocus ? 0.12 : 0.07)
            TIcon { id: si; x: 13; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; opacity: 0.7 }
            TextInput {
                id: search
                x: si.x + si.width + 9
                width: parent.width - x - 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.label
                selectionColor: Theme.violet
                font.family: Theme.font
                font.pixelSize: 12
                clip: true
                onTextChanged: root.query = text
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search processes or PID"
                    color: Theme.fg(0.4)
                    font: search.font
                }
            }
            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: search.forceActiveFocus() }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Showing " + root.rows.length + " / " + SysMon.procs.length
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }
    }

    // ---------------- tiêu đề cột ----------------
    readonly property real colName: width - 360
    Row {
        id: header
        x: 14
        y: bar.height + 10
        height: 22
        Text { width: root.colName - 14; text: "Name"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        Text { width: 60; horizontalAlignment: Text.AlignRight; text: "PID"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        Text { width: 80; horizontalAlignment: Text.AlignRight; text: "User"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        SortHead { width: 64; label: "CPU"; key: "cpu" }
        SortHead { width: 80; label: "Memory"; key: "mem" }
    }

    component SortHead: Text {
        property string label: ""
        property string key: ""
        horizontalAlignment: Text.AlignRight
        text: label + (root.sortBy === key ? " ▾" : "")
        color: root.sortBy === key ? Theme.label : sh.containsMouse ? Theme.labelSoft : Theme.muted
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Bold
        MouseArea { id: sh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sortBy = parent.key }
    }

    // ---------------- danh sách ----------------
    ListView {
        y: header.y + header.height + 4
        width: parent.width
        height: parent.height - y
        clip: true
        spacing: 2
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property int pid: modelData[0]
            readonly property bool termed: root.termSent[pid] !== undefined
            width: ListView.view.width
            height: 34
            radius: 10
            color: rm.hovered ? Theme.fg(0.08) : index % 2 ? Theme.fg(0.02) : "transparent"
            HoverHandler { id: rm }

            Row {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: root.colName - 14
                    text: row.modelData[2]
                    elide: Text.ElideRight
                    color: Theme.label
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Text {
                    width: 60; horizontalAlignment: Text.AlignRight
                    text: row.pid
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; font.features: ({ "tnum": 1 })
                }
                Text {
                    width: 80; horizontalAlignment: Text.AlignRight
                    text: row.modelData[5]
                    elide: Text.ElideRight
                    color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
                }
                Text {
                    width: 64; horizontalAlignment: Text.AlignRight
                    text: row.modelData[3].toFixed(1) + "%"
                    color: row.modelData[3] > 50 ? "#FF6B97" : row.modelData[3] > 10 ? "#FFB547" : Theme.label
                    font.family: Theme.font; font.pixelSize: 12; font.features: ({ "tnum": 1 })
                }
                Text {
                    width: 80; horizontalAlignment: Text.AlignRight
                    text: SysMon.bytes(row.modelData[4])
                    color: Theme.label; font.family: Theme.font; font.pixelSize: 12; font.features: ({ "tnum": 1 })
                }
            }

            PillButton {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                visible: rm.hovered || row.termed
                label: row.termed ? "Force quit" : "End task"
                danger: true
                armed: row.termed
                onClicked: {
                    if (row.termed) {
                        SysMon.kill(row.pid, true);
                    } else {
                        SysMon.kill(row.pid, false);
                        const t = Object.assign({}, root.termSent);
                        t[row.pid] = Date.now();
                        root.termSent = t;
                    }
                }
            }
        }
    }
}
