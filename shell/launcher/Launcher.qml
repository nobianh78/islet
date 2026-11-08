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
    readonly property var hiddenIds: ["qv4l2", "qvidcap", "stoken-gui", "stoken-gui-small", "org.quickshell",
        "org.gnome.NautilusPreviewer", "org.gnome.Papers-previewer",          // Quick Look: bấm Space trong Files
        "org.kde.kdeconnect.app", "org.kde.kdeconnect.nonplasma"]           // điện thoại: Cài đặt › Phone
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

    // ---------------- kéo thả & ghim vào dock ----------------
    property var dragApp: null
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property bool dropHovered: false
    property int dropIndex: -1

    // ---------------- menu chuột phải ----------------
    property var menuApp: null
    property real menuX: 0
    property real menuY: 0
    property bool menuOpen: false

    // Kích thước ước lượng của Dock để nhận diện vùng thả
    readonly property real dockItemBase: Prefs.dockSize
    readonly property real dockGap: 8
    readonly property real dockSep: 17
    readonly property real dockPad: 8
    readonly property int pinnedCount: DockPins.pins.length
    readonly property int unpinnedRunningCount: {
        const tl = ToplevelManager.toplevels?.values ?? [];
        let count = 0;
        const pinned = DockPins.pins;
        for (let i = 0; i < tl.length; i++) {
            const cls = tl[i].appId;
            if (!cls || cls === "org.quickshell" || cls === "org.gnome.NautilusPreviewer") continue;
            if (pinned.indexOf(cls) >= 0) continue;
            count++;
        }
        return count;
    }
    // Launcher icon (1) + Pinned + Unpinned running + Settings icon (1)
    readonly property int totalDockItems: 1 + pinnedCount + unpinnedRunningCount + 1
    readonly property real dockWidth: totalDockItems * (dockItemBase + dockGap) + dockSep + dockPad * 2

    function startDrag(app, gx, gy) {
        if (menuOpen) menuOpen = false;
        dragApp = app;
        dragX = gx;
        dragY = gy;
        dragging = true;
        checkDropHover(gx, gy);
    }

    function updateDrag(gx, gy) {
        dragX = gx;
        dragY = gy;
        checkDropHover(gx, gy);
    }

    function checkDropHover(gx, gy) {
        const isNearBottom = gy >= (win.height - 130);
        const dLeft = (win.width - dockWidth) / 2 - 60;
        const dRight = (win.width + dockWidth) / 2 + 60;
        const inZone = isNearBottom && (gx >= dLeft && gx <= dRight);

        dropHovered = inZone;
        Ui.dockDropHover = inZone;

        if (inZone) {
            const firstPinX = (win.width - dockWidth) / 2 + dockPad + (dockItemBase + dockGap);
            const relX = gx - firstPinX;
            const slot = Math.round(relX / (dockItemBase + dockGap));
            dropIndex = Math.max(0, Math.min(pinnedCount, slot));
        } else {
            dropIndex = -1;
        }
    }

    function endDrag(gx, gy) {
        checkDropHover(gx, gy);
        if (dropHovered && dragApp) {
            const id = dragApp.id;
            const name = nameOf(dragApp);
            const icon = iconOf(dragApp);
            DockPins.pinAt(id, dropIndex >= 0 ? dropIndex : -1);
            Ui.toast("Pinned " + name + " to the Dock", icon, "");
        }
        dragging = false;
        dragApp = null;
        dropHovered = false;
        dropIndex = -1;
        Ui.dockDropHover = false;
    }

    function openMenu(app, gx, gy) {
        menuApp = app;
        menuX = gx;
        menuY = gy;
        menuOpen = true;
    }

    onOpenChanged: {
        if (open) {
            query = "";
            search.text = "";
            pager.positionViewAtBeginning();
            intro.restart();
            search.forceActiveFocus();
        } else {
            dragging = false;
            dragApp = null;
            dropHovered = false;
            dropIndex = -1;
            menuOpen = false;
            Ui.dockDropHover = false;
        }
    }
    onQueryChanged: pager.positionViewAtBeginning()

    // ---------------- nền ----------------
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.surface(0.55)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? 220 : 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (win.menuOpen) win.menuOpen = false;
                else Ui.launcherOpen = false;
            }
            onWheel: w => pager.turn(w.angleDelta.y < 0 || w.angleDelta.x < 0 ? 1 : -1)
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: bg.opacity
        scale: win.open ? 1 : 1.06
        Behavior on scale { NumberAnimation { duration: win.open ? 420 : 200; easing.type: win.open ? Easing.OutQuint : Easing.InCubic } }

        Keys.onEscapePressed: {
            if (win.menuOpen) win.menuOpen = false;
            else Ui.launcherOpen = false;
        }

        // ---------------- tìm kiếm ----------------
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: 70
            width: 380
            height: 42
            radius: 21
            color: Theme.fg(search.activeFocus ? 0.16 : 0.10)
            border.width: 1
            border.color: Theme.fg(0.18)
            Behavior on color { ColorAnimation { duration: 150 } }

            TIcon {
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
                color: Theme.label
                selectionColor: Theme.violet
                font.family: Theme.font
                font.pixelSize: 14
                clip: true
                onTextChanged: win.query = text
                onAccepted: if (win.apps.length > 0) win.launch(win.apps[0])
                Keys.onEscapePressed: {
                    if (win.menuOpen) win.menuOpen = false;
                    else Ui.launcherOpen = false;
                }
                Keys.onLeftPressed: e => { if (text === "") pager.turn(-1); else e.accepted = false; }
                Keys.onRightPressed: e => { if (text === "") pager.turn(1); else e.accepted = false; }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Search apps"
                    color: Theme.fg(0.45)
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
            interactive: win.pages > 1 && !win.dragging

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
                                scale: m.pressed && !m.dragActive ? 0.86 : m.containsMouse ? 1.08 : 1
                                opacity: win.dragging && win.dragApp === cell.modelData ? 0.35 : 1
                                Behavior on scale { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.003 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                // nền sáng khi rê
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 92
                                    height: 92
                                    radius: 26
                                    color: Theme.fg(m.containsMouse && !win.dragging ? 0.10 : 0)
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
                                color: Theme.label
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
                                cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                preventStealing: true

                                property real pressX: 0
                                property real pressY: 0
                                property bool dragActive: false

                                onPressed: mouse => {
                                    if (mouse.button === Qt.RightButton) return;
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                    dragActive = false;
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) return;
                                    const dx = mouse.x - pressX;
                                    const dy = mouse.y - pressY;
                                    if (!dragActive && (dx * dx + dy * dy > 64)) {
                                        dragActive = true;
                                        const pt = mapToItem(content, mouse.x, mouse.y);
                                        win.startDrag(cell.modelData, pt.x, pt.y);
                                    }
                                    if (dragActive) {
                                        const pt = mapToItem(content, mouse.x, mouse.y);
                                        win.updateDrag(pt.x, pt.y);
                                    }
                                }

                                onReleased: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        const pt = mapToItem(content, mouse.x, mouse.y);
                                        win.openMenu(cell.modelData, pt.x, pt.y);
                                        return;
                                    }
                                    if (dragActive) {
                                        const pt = mapToItem(content, mouse.x, mouse.y);
                                        win.endDrag(pt.x, pt.y);
                                        dragActive = false;
                                    } else {
                                        win.launch(cell.modelData);
                                    }
                                }
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
            color: Theme.fg(0.6)
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
                    color: cur ? Theme.label : Theme.fg(0.35)
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

        // ---------------- Vùng Dock thả ghim (hiện khi đang kéo) ----------------
        Glass {
            id: dropZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: Math.max(380, win.dockWidth + 48)
            height: Prefs.dockSize + 20
            radius: height / 2
            z: 998
            visible: opacity > 0.01

            color: win.dropHovered
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                : Theme.fg(0.09)
            border.color: win.dropHovered ? Theme.accent : Theme.fg(0.25)
            border.width: win.dropHovered ? 2 : 1
            scale: win.dragging ? (win.dropHovered ? 1.04 : 1.0) : 0.92
            opacity: win.dragging ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.005 } }
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                anchors.centerIn: parent
                spacing: 8
                TIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "pin"
                    size: 16
                    color: win.dropHovered ? Theme.label : Theme.fg(0.7)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.dropHovered ? "Drop to pin to the Dock" : "Drag here to pin to the Dock"
                    color: Theme.label
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: win.dropHovered ? Font.Bold : Font.Medium
                }
            }
        }

        // ---------------- Icon đang được kéo theo con trỏ ----------------
        Item {
            id: dragProxy
            visible: win.dragging && win.dragApp !== null
            x: win.dragX - width / 2
            y: win.dragY - height / 2
            width: 76
            height: 76
            z: 9999

            // Nền quầng sáng mờ xung quanh
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 16
                height: parent.height + 16
                radius: width / 2
                color: win.dropHovered ? Theme.accent : Theme.fg(0.2)
                opacity: win.dropHovered ? 0.45 : 0.25
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Icon app
            AppIcon {
                anchors.centerIn: parent
                size: 68
                name: win.dragApp ? (Theme.appKey(win.dragApp.id) || Theme.appKey(win.dragApp.icon)) : ""
                source: win.dragApp ? win.iconOf(win.dragApp) : ""
                scale: win.dropHovered ? 1.15 : 1.05
                Behavior on scale { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.005 } }
            }

            // Huy hiệu "+" khi rê vào Dock
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -4
                anchors.rightMargin: -4
                width: 24
                height: 24
                radius: 12
                color: win.dropHovered ? Theme.accent : Qt.rgba(0.1, 0.1, 0.15, 0.85)
                border.color: Theme.label
                border.width: 1.5
                scale: win.dropHovered ? 1.2 : 0.8
                opacity: win.dropHovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; epsilon: 0.01 } }

                TIcon {
                    anchors.centerIn: parent
                    name: "plus"
                    size: 13
                    color: Theme.label
                }
            }
        }

        // ---------------- Menu chuột phải cho app trong Launcher ----------------
        Item {
            id: ctxMenu
            visible: win.menuOpen
            x: Math.max(12, Math.min(win.width - width - 12, win.menuX))
            y: Math.max(12, Math.min(win.height - height - 12, win.menuY))
            width: 210
            height: menuCol.implicitHeight + 16
            z: 10000

            MouseArea {
                anchors.fill: parent
                // chặn click xuyên qua nền
            }

            Glass {
                anchors.fill: parent
                radius: 16
                color: Theme.surface(0.94)
                border.color: Theme.fg(0.18)

                Column {
                    id: menuCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    // Tiêu đề: Tên app
                    Row {
                        width: parent.width
                        height: 28
                        leftPadding: 6
                        spacing: 8
                        AppIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 20
                            name: win.menuApp ? (Theme.appKey(win.menuApp.id) || Theme.appKey(win.menuApp.icon)) : ""
                            source: win.menuApp ? win.iconOf(win.menuApp) : ""
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34
                            text: win.menuApp ? win.nameOf(win.menuApp) : ""
                            elide: Text.ElideRight
                            color: Theme.label
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    // Vạch ngăn
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.fg(0.1)
                    }

                    // Nút Ghim / Bỏ ghim
                    Rectangle {
                        id: pinBtn
                        readonly property bool pinned: win.menuApp ? DockPins.isPinned(win.menuApp.id) : false
                        width: parent.width
                        height: 32
                        radius: 8
                        color: pinHover.containsMouse ? Theme.fg(0.12) : "transparent"
                        Row {
                            anchors.fill: parent
                            leftPadding: 8
                            spacing: 8
                            TIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "pin"
                                size: 14
                                color: Theme.accent
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pinBtn.pinned ? "Unpin from Dock" : "Pin to Dock"
                                color: Theme.label
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: pinHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.menuApp) {
                                    if (pinBtn.pinned) {
                                        DockPins.unpin(win.menuApp.id);
                                        Ui.toast("Unpinned " + win.nameOf(win.menuApp) + " from the Dock", win.iconOf(win.menuApp), "");
                                    } else {
                                        DockPins.pin(win.menuApp.id);
                                        Ui.toast("Pinned " + win.nameOf(win.menuApp) + " to the Dock", win.iconOf(win.menuApp), "");
                                    }
                                }
                                win.menuOpen = false;
                            }
                        }
                    }

                    // Nút Mở ứng dụng
                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 8
                        color: openHover.containsMouse ? Theme.fg(0.12) : "transparent"
                        Row {
                            anchors.fill: parent
                            leftPadding: 8
                            spacing: 8
                            TIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "plus"
                                size: 14
                                color: Theme.label
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Open"
                                color: Theme.label
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: openHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.menuApp) win.launch(win.menuApp);
                                win.menuOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // tín hiệu "mới mở" cho các ô chạy lại animation
    Timer { id: intro; interval: 1 }
}
