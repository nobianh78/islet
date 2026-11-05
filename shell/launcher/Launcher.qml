import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Trình xem tất cả ứng dụng kiểu iPad.
//   Mở: nút "Ứng dụng" trên dock hoặc Super+Space · Đóng: Esc / bấm chỗ trống / mở một app
//   Gõ để tìm (Enter mở kết quả đầu) · Lưới 7×4 chia trang: vuốt, lăn chuột, ← →
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool open: Ui.launcherOpen
    // giữ cửa sổ trong lúc chạy animation đóng
    visible: open || bg.opacity > 0.01

    readonly property int cols: 7
    readonly property int rows: 4
    readonly property int perPage: cols * rows
    readonly property int cellW: 124
    readonly property int cellH: 122

    property string query: ""

    // ---------------- danh sách app ----------------
    // Ẩn app chạy trong terminal (vim, lftp…) và tiện ích kỹ thuật đi kèm thư viện, như iPad chỉ hiện app thật.
    readonly property var hiddenIds: ["qv4l2", "qvidcap", "stoken-gui", "stoken-gui-small", "org.quickshell"]
    // Tên tiếng Việt cho các app chính
    readonly property var niceNames: ({
        "org.gnome.Nautilus": "Files",
        "kitty": "Terminal",
        "mpv": "Video Player",
        "firefox": "Firefox"
    })
    function nameOf(e) { return niceNames[e.id] ?? e.name; }

    readonly property var allApps: {
        const list = DesktopEntries.applications.values.filter(e =>
            !e.noDisplay && !e.runInTerminal && hiddenIds.indexOf(e.id) < 0);
        return list.slice().sort((a, b) => nameOf(a).localeCompare(nameOf(b), "vi"));
    }
    function norm(s) { return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d"); }
    readonly property var apps: {
        const q = norm(query.trim());
        if (!q) return allApps;
        return allApps.filter(e => norm(nameOf(e)).includes(q) || norm(e.name).includes(q) || norm(e.genericName).includes(q)
            || (e.keywords || []).some(k => norm(k).includes(q)));
    }
    readonly property int pages: Math.max(1, Math.ceil(apps.length / perPage))

    function iconOf(e) {
        return Quickshell.iconPath(e.icon, true) || Quickshell.iconPath("application-x-executable", true);
    }
    function launch(e) {
        if (e.id === "islet-store" || e.id === "islet-installer" || e.id === "islet-settings") { Ui.launchEntry(e); return; }
        Ui.announceLaunchUrl(nameOf(e), iconOf(e), Theme.appKey(e.id) || Theme.appKey(e.icon));
        e.execute();
        Ui.launcherOpen = false;
    }

    onOpenChanged: {
        if (open) {
            query = "";
            search.text = "";
            pager.positionViewAtBeginning();
            intro.restart();
            search.forceActiveFocus();
        }
    }
    onQueryChanged: pager.positionViewAtBeginning()

    // ---------------- nền ----------------
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.04, 0.08, 0.55)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? 220 : 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.launcherOpen = false
            onWheel: w => pager.turn(w.angleDelta.y < 0 || w.angleDelta.x < 0 ? 1 : -1)
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: bg.opacity
        scale: win.open ? 1 : 1.06
        Behavior on scale { NumberAnimation { duration: win.open ? 420 : 200; easing.type: win.open ? Easing.OutQuint : Easing.InCubic } }

        Keys.onEscapePressed: Ui.launcherOpen = false

        // ---------------- tìm kiếm ----------------
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: 70
            width: 380
            height: 42
            radius: 21
            color: Qt.rgba(1, 1, 1, search.activeFocus ? 0.16 : 0.10)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)
            Behavior on color { ColorAnimation { duration: 150 } }

            Icon {
                id: sIcon
                x: 15
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 17
                opacity: 0.75
            }
            TextInput {
                id: search
                x: sIcon.x + sIcon.width + 10
                width: parent.width - x - 16
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                selectionColor: Theme.violet
                font.family: Theme.font
                font.pixelSize: 14
                clip: true
                onTextChanged: win.query = text
                onAccepted: if (win.apps.length > 0) win.launch(win.apps[0])
                Keys.onEscapePressed: Ui.launcherOpen = false
                Keys.onLeftPressed: e => { if (text === "") pager.turn(-1); else e.accepted = false; }
                Keys.onRightPressed: e => { if (text === "") pager.turn(1); else e.accepted = false; }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search apps"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font: search.font
                }
            }
        }

        // ---------------- lưới app chia trang ----------------
        ListView {
            id: pager
            anchors.horizontalCenter: parent.horizontalCenter
            y: searchBox.y + searchBox.height + 46
            width: win.cols * win.cellW
            height: win.rows * win.cellH
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 380
            clip: false
            model: win.pages
            interactive: win.pages > 1

            function turn(d) {
                currentIndex = Math.max(0, Math.min(count - 1, currentIndex + d));
            }

            delegate: Item {
                id: page
                required property int index
                width: pager.width
                height: pager.height

                Grid {
                    columns: win.cols
                    Repeater {
                        model: win.apps.slice(page.index * win.perPage, (page.index + 1) * win.perPage)

                        Item {
                            id: cell
                            required property var modelData
                            required property int index
                            width: win.cellW
                            height: win.cellH

                            // hiện lần lượt khi mở
                            opacity: 0
                            scale: 0.7
                            Connections {
                                target: intro
                                function onTriggered() { cell.opacity = 0; cell.scale = 0.7; pop.restart(); }
                            }
                            Component.onCompleted: pop.restart()
                            SequentialAnimation {
                                id: pop
                                PauseAnimation { duration: Math.min(14, (cell.index % win.cols) + Math.floor(cell.index / win.cols)) * 22 }
                                ParallelAnimation {
                                    NumberAnimation { target: cell; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: cell; property: "scale"; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                                }
                            }

                            Item {
                                id: iconBox
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 8
                                width: 72
                                height: 72
                                scale: m.pressed ? 0.86 : m.containsMouse ? 1.08 : 1
                                Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.003 } }

                                // nền sáng khi rê
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 92
                                    height: 92
                                    radius: 26
                                    color: Qt.rgba(1, 1, 1, m.containsMouse ? 0.10 : 0)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    size: 66
                                    name: Theme.appKey(cell.modelData.id) || Theme.appKey(cell.modelData.icon)
                                    source: win.iconOf(cell.modelData)
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: iconBox.y + iconBox.height + 10
                                width: win.cellW - 12
                                horizontalAlignment: Text.AlignHCenter
                                text: win.nameOf(cell.modelData)
                                elide: Text.ElideRight
                                color: "#FFFFFF"
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: m
                                anchors.fill: parent
                                anchors.margins: 6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.launch(cell.modelData)
                            }
                        }
                    }
                }
            }
        }

        // không tìm thấy
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: pager.y + 80
            visible: win.apps.length === 0
            text: "Nothing found for “" + win.query + "”"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: Theme.font
            font.pixelSize: 15
        }

        // chấm trang
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: pager.y + pager.height + 22
            spacing: 9
            visible: win.pages > 1
            Repeater {
                model: win.pages
                Rectangle {
                    required property int index
                    readonly property bool cur: pager.currentIndex === index
                    width: cur ? 22 : 8
                    height: 8
                    radius: 4
                    color: cur ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.35)
                    Behavior on width { SpringAnimation { spring: 4.5; damping: 0.3; epsilon: 0.05 } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pager.currentIndex = parent.index
                    }
                }
            }
        }
    }

    // tín hiệu "mới mở" cho các ô chạy lại animation
    Timer { id: intro; interval: 1 }
}
