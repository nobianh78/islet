import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"
import "../services"
import "../common"
import "Catalog.js" as Catalog

// Cửa hàng ứng dụng Islet: Khám phá · nhóm app · Đã cài · tìm trong toàn bộ kho Arch.
// Mở: "Cửa hàng" trên dock / trong lưới Ứng dụng, hoặc `qs ipc call store open`.
PanelWindow {
    id: win

    implicitWidth: 980
    implicitHeight: 640
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-store"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool open: Ui.storeOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    property string section: "discover"      // discover | <category id> | installed
    property string query: ""

    onOpenChanged: if (open) {
        Packages.watch = Catalog.apps.filter(a => !a.pkgs).map(a => a.pkg);
        Packages.refresh();
        Packages.fetchSizes(Catalog.apps.filter(a => !a.pkgs).map(a => a.pkg));
        searchInput.forceActiveFocus();
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: if (!Packages.askPassword) Ui.storeOpen = false
    }

    // ---------------- tiện ích ----------------
    function entryOf(pkg) {
        // app (không ẩn) đầu tiên mà gói đã cài
        for (const id of (Packages.desktops[pkg] || [])) {
            const e = DesktopEntries.byId(id);
            if (e && !e.noDisplay) return e;
        }
        return DesktopEntries.byId(pkg) ?? DesktopEntries.heuristicLookup(pkg);
    }
    // Icon thật: app đã cài → icon của app; app chọn sẵn → shell/assets/store/<gói>.png
    // (scripts/fetch-store-icons.sh); kết quả tìm → icon appstream của Arch.
    readonly property var bundled: Catalog.apps.filter(a => !a.pkgs).map(a => a.pkg)
    function appInstalled(app) {
        Packages.installed;
        return app.pkgs ? app.pkgs.every(p => Packages.isInstalled(p)) : Packages.isInstalled(app.pkg);
    }
    function iconOf(pkg) {
        Packages.desktops; Packages.installed;
        if (Packages.isInstalled(pkg)) {
            const e = entryOf(pkg);
            const p = e ? (Quickshell.iconPath(e.icon, true) || "") : "";
            if (p) return p;
        }
        if (bundled.indexOf(pkg) >= 0) return Qt.resolvedUrl("../assets/store/" + pkg + ".png");
        return Packages.appIcons[pkg] ?? "";
    }
    function openApp(app) {
        if (app.cli) Quickshell.execDetached(["kitty", "sh", "-c", app.cli]);
        else { const e = entryOf(app.pkg); if (e) e.execute(); }
        Ui.storeOpen = false;
    }
    // Kết quả tìm: chỉ app có icon thật (app trong danh sách chọn sẵn, app đã cài, app có trong appstream);
    // còn lại là công cụ dòng lệnh / thư viện → không hiện, chỉ đếm.
    readonly property var appResults: {
        Packages.appIcons; Packages.installed;
        return Packages.results.filter(r => win.iconOf(r.pkg) !== "");
    }
    readonly property var shown: {
        Packages.installed;
        if (section === "installed") return Catalog.apps.filter(a => win.appInstalled(a));
        if (section === "discover") return Catalog.apps.filter(a => a.featured);
        return Catalog.apps.filter(a => a.cat === section);
    }

    // ================= khung =================
    Glass {
        id: panel
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0.05, 0.05, 0.09, 0.9)

        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.002 } }

        Keys.onEscapePressed: Ui.storeOpen = false

        // ---------------- cột trái ----------------
        Rectangle {
            id: side
            width: 214
            height: parent.height
            radius: 28
            color: Qt.rgba(1, 1, 1, 0.03)

            Row {
                x: 20; y: 22; spacing: 10
                Image { width: 32; height: 32; sourceSize: Qt.size(64, 64); source: Theme.appIcon("store") }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Store"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
            }

            Column {
                x: 12; y: 74
                width: parent.width - 24
                spacing: 2
                NavItem { key: "discover"; icon: "sparkle"; label: "Discover" }
                Item { width: 1; height: 8 }
                Repeater {
                    model: Catalog.categories
                    NavItem { required property var modelData; key: modelData.id; icon: modelData.icon; label: modelData.label }
                }
                Item { width: 1; height: 8 }
                NavItem {
                    key: "installed"; icon: "check-circle"; label: "Installed"
                    badge: { Packages.installed; return String(Catalog.apps.filter(a => win.appInstalled(a)).length); }
                }
            }

            // việc đang chạy
            Rectangle {
                visible: Packages.current !== null
                x: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                width: parent.width - 24
                height: 58
                radius: 16
                color: Theme.tint(0.16)
                Column {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24
                    spacing: 6
                    Text {
                        width: parent.width
                        text: (Packages.current?.op === "remove" ? "Removing " : "Installing ") + (Packages.current?.name ?? "")
                            + (Packages.queue.length ? "  (+" + Packages.queue.length + ")" : "")
                        elide: Text.ElideRight
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    Rectangle {
                        width: parent.width; height: 5; radius: 3; color: Qt.rgba(1, 1, 1, 0.12)
                        Rectangle {
                            height: parent.height; radius: 3; color: Theme.violet
                            width: parent.width * Packages.pct / 100
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                }
            }
        }

        // ---------------- phần chính ----------------
        Item {
            id: main
            x: side.width + 22
            y: 20
            width: parent.width - x - 22
            height: parent.height - 40

            // tìm + đóng
            Rectangle {
                id: searchBox
                width: main.width - 44
                height: 40
                radius: 20
                color: Qt.rgba(1, 1, 1, searchInput.activeFocus ? 0.12 : 0.07)
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.tint(0.7) : Qt.rgba(1, 1, 1, 0.08)
                Icon { id: si; x: 15; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; opacity: 0.75 }
                TextInput {
                    id: searchInput
                    x: si.x + si.width + 10
                    width: parent.width - x - 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFF"; selectionColor: Theme.violet
                    font.family: Theme.font; font.pixelSize: 13
                    clip: true
                    onTextChanged: { win.query = text; Packages.search(text); }
                    Keys.onEscapePressed: { if (text) text = ""; else Ui.storeOpen = false; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Search over 14,000 apps and packages…"
                        color: Qt.rgba(1, 1, 1, 0.4); font: searchInput.font
                    }
                }
                MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: searchInput.forceActiveFocus() }
            }
            Rectangle {
                anchors.right: parent.right
                width: 32; height: 32; radius: 16; y: 4
                color: xm.containsMouse ? "#FF5F57" : Qt.rgba(1, 1, 1, 0.08)
                Icon { anchors.centerIn: parent; name: "close"; size: 14 }
                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.storeOpen = false }
            }

            // nội dung cuộn
            Flickable {
                id: flick
                y: searchBox.height + 18
                width: main.width
                height: main.height - y
                contentHeight: body.implicitHeight + 20
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: flick.width
                    spacing: 16

                    // ---- banner Khám phá ----
                    Rectangle {
                        visible: win.query === "" && win.section === "discover"
                        width: parent.width
                        height: 150
                        radius: 24
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#6D4AFF" }
                            GradientStop { position: 0.55; color: "#B65CFF" }
                            GradientStop { position: 1; color: "#FF6FB5" }
                        }
                        Column {
                            x: 28; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text { text: "Apps for Islet"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 24; font.weight: Font.Bold }
                            Text {
                                width: 420; wrapMode: Text.WordWrap
                                text: "Pick an app and hit Install — Islet does the rest. New apps show up right in your app grid."
                                color: Qt.rgba(1, 1, 1, 0.85); font.family: Theme.font; font.pixelSize: 13
                            }
                        }
                        Grid {
                            anchors.right: parent.right; anchors.rightMargin: 28; anchors.verticalCenter: parent.verticalCenter
                            columns: 3; spacing: 10
                            Repeater {
                                model: Catalog.categories.slice(0, 6)
                                Rectangle {
                                    required property var modelData
                                    width: 46; height: 46; radius: 14
                                    color: Qt.rgba(1, 1, 1, 0.2)
                                    Icon { anchors.centerIn: parent; name: parent.modelData.icon; size: 22 }
                                }
                            }
                        }
                    }

                    // ---- tiêu đề mục ----
                    Text {
                        visible: win.query === ""
                        text: win.section === "discover" ? "Featured"
                            : win.section === "installed" ? "Installed from the Store"
                            : Catalog.category(win.section).label
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.Bold
                    }

                    // ---- lưới app chọn sẵn ----
                    Grid {
                        visible: win.query === ""
                        columns: 2
                        spacing: 12
                        Repeater {
                            model: win.shown
                            AppCard {
                                required property var modelData
                                app: modelData
                                width: (body.width - 12) / 2
                            }
                        }
                    }
                    Text {
                        visible: win.query === "" && win.shown.length === 0
                        text: win.section === "installed" ? "No apps installed from the Store yet." : ""
                        color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 13
                    }

                    // ---- Khám phá: thêm từng nhóm ----
                    Repeater {
                        model: win.query === "" && win.section === "discover" ? Catalog.categories : []
                        Column {
                            required property var modelData
                            width: body.width
                            spacing: 10
                            Item {
                                width: parent.width; height: 26
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.icon; size: 17 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold }
                                }
                                Text {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    text: "See all ›"; color: am.containsMouse ? "#FFFFFF" : Theme.violet
                                    font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                                    MouseArea { id: am; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.section = modelData.id; flick.contentY = 0; } }
                                }
                            }
                            Grid {
                                columns: 2; spacing: 12
                                Repeater {
                                    model: Catalog.apps.filter(a => a.cat === modelData.id && !a.featured).slice(0, 4)
                                    AppCard { required property var modelData; app: modelData; width: (body.width - 12) / 2 }
                                }
                            }
                        }
                    }

                    // ---- kết quả tìm ----
                    Text {
                        visible: win.query !== ""
                        text: Packages.searching ? "Searching…"
                            : win.appResults.length === 0 ? "No apps match “" + win.query + "”"
                            : win.appResults.length + " apps for “" + win.query + "”"
                        color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 13
                    }
                    Repeater {
                        model: win.query !== "" ? win.appResults : []
                        AppCard {
                            required property var modelData
                            width: body.width
                            wide: true
                            app: Catalog.byPkg(modelData.pkg) ?? { pkg: modelData.pkg, name: modelData.pkg, desc: modelData.desc, cat: "tools", ver: modelData.ver, repo: modelData.repo }
                        }
                    }
                    Text {
                        visible: win.query !== "" && !Packages.searching && Packages.results.length > win.appResults.length
                        text: "… and " + (Packages.results.length - win.appResults.length) + " more packages (command-line tools, libraries) not shown here"
                        color: "#636366"; font.family: Theme.font; font.pixelSize: 11
                    }
                }
            }
        }

        // ================= hộp nhập mật khẩu =================
        Rectangle {
            anchors.fill: parent
            radius: 28
            visible: Packages.askPassword
            color: Qt.rgba(0, 0, 0, 0.55)
            MouseArea { anchors.fill: parent }
            onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus(); }

            Glass {
                anchors.centerIn: parent
                width: 380; height: 210; radius: 24
                color: Qt.rgba(0.08, 0.08, 0.13, 0.97)
                Column {
                    x: 24; y: 22; width: parent.width - 48; spacing: 12
                    Row {
                        spacing: 10
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 20; color: Theme.violet }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Password required"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: "Enter your password to " + (Packages.queue[0]?.op === "remove" ? "remove " : "install ") + (Packages.queue[0]?.name ?? "")
                        color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 12
                    }
                    Rectangle {
                        width: parent.width; height: 40; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: Theme.violet
                        TextInput {
                            id: pw
                            x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14
                            onAccepted: if (text) Packages.submitPassword(text)
                            Keys.onEscapePressed: Packages.cancelPassword()
                        }
                    }
                    Row {
                        anchors.right: parent.right; spacing: 8
                        PillBtn { label: "Cancel"; onClicked: Packages.cancelPassword() }
                        PillBtn { label: "Continue"; primary: true; onClicked: if (pw.text) Packages.submitPassword(pw.text) }
                    }
                }
            }
        }
    }

    Connections {
        target: Packages
        function onPasswordRejected() { Packages.askPassword = false; }
    }

    // ================= thành phần =================
    component NavItem: Rectangle {
        id: n
        property string key: ""
        property string icon: ""
        property string label: ""
        property string badge: ""
        readonly property bool on: win.query === "" && win.section === key
        width: parent.width
        height: 36
        radius: 12
        color: on ? Theme.tint(0.22) : nm.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
        Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: n.icon; size: 17; opacity: n.on ? 1 : 0.8 }
        Text { x: 42; anchors.verticalCenter: parent.verticalCenter; text: n.label; color: n.on ? "#FFFFFF" : "#D1D1D6"; font.family: Theme.font; font.pixelSize: 13; font.weight: n.on ? Font.DemiBold : Font.Normal }
        Text { visible: n.badge !== "" && n.badge !== "0"; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: n.badge; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
        MouseArea {
            id: nm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { win.section = n.key; searchInput.text = ""; flick.contentY = 0; }
        }
    }

    component PillBtn: Rectangle {
        id: pb
        property string label: ""
        property bool primary: false
        property color tint: Theme.violet
        signal clicked()
        width: pl.implicitWidth + 30
        height: 32
        radius: 16
        color: primary ? (pm.containsMouse ? Qt.lighter(tint, 1.15) : tint) : (pm.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09))
        Behavior on color { ColorAnimation { duration: 130 } }
        scale: pm.pressed ? 0.94 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
        Text { id: pl; anchors.centerIn: parent; text: pb.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Bold }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
    }

    component AppCard: Rectangle {
        id: card
        property var app: ({})
        property bool wide: false
        readonly property var cat: Catalog.category(app.cat)
        readonly property bool inst: { Packages.installed; return win.appInstalled(app); }
        readonly property bool isBundle: (app.pkgs?.length ?? 0) > 0
        readonly property var job: { Packages.current; Packages.queue; return Packages.jobOf(app.pkg); }
        readonly property bool running: Packages.current?.pkg === app.pkg
        readonly property string err: Packages.lastError[app.pkg] ?? ""
        readonly property string realIcon: {
            Packages.installed; Packages.appIcons;
            return app.icon ? Theme.appIcon(app.icon) : win.iconOf(app.pkg);
        }

        height: wide ? 70 : 92
        radius: 20
        color: cm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.05)
        Behavior on color { ColorAnimation { duration: 140 } }
        HoverHandler { id: cm }

        // icon: icon thật nếu đã cài, không thì ô gradient theo nhóm + chữ cái đầu
        Item {
            id: ic
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: card.wide ? 44 : 60
            height: width
            Rectangle {
                anchors.fill: parent
                visible: card.realIcon === "" || cardImg.status === Image.Error
                radius: width * 0.28
                gradient: Gradient {
                    GradientStop { position: 0; color: card.cat.from }
                    GradientStop { position: 1; color: card.cat.to }
                }
                Text {
                    anchors.centerIn: parent
                    text: (card.app.name || "?").charAt(0).toUpperCase()
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: parent.width * 0.44; font.weight: Font.Bold
                }
            }
            Image {
                id: cardImg
                anchors.fill: parent
                visible: card.realIcon !== "" && status !== Image.Error
                source: card.realIcon
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(width * 2, height * 2)
            }
        }

        Column {
            anchors.left: ic.right
            anchors.leftMargin: 14
            anchors.right: action.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: card.app.name + (card.app.ver ? "  ·  " + card.app.ver : "")
                elide: Text.ElideRight
                color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: card.err ? card.err : card.running ? Packages.stepText : card.app.desc
                elide: Text.ElideRight
                maximumLineCount: card.wide ? 1 : 2
                wrapMode: Text.Wrap
                color: card.err ? "#FF8A8A" : card.running ? Qt.lighter(Theme.violet, 1.3) : "#8E8E93"
                font.family: Theme.font; font.pixelSize: 12
            }
            Text {
                visible: !card.wide && (card.isBundle || card.app.aur || Packages.sizes[card.app.pkg] !== undefined)
                text: card.isBundle ? card.app.pkgs.length + " packages · " + card.app.pkgs.map(p => p.replace(/^aur\//, "")).join(", ")
                    : card.app.aur ? "AUR · community package, built on your machine"
                    : "Download " + (Packages.sizes[card.app.pkg]?.dl ?? "") + " · installed " + (Packages.sizes[card.app.pkg]?.inst ?? "")
                elide: Text.ElideRight
                width: parent.width
                color: "#636366"; font.family: Theme.font; font.pixelSize: 10
            }
        }

        // nút: Cài · vòng tiến trình · Mở / Gỡ
        Row {
            id: action
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // tiến trình
            Item {
                visible: card.job !== null
                width: 36; height: 36
                Canvas {
                    id: ring
                    anchors.fill: parent
                    property real p: card.running ? Packages.pct / 100 : 0
                    onPChanged: requestPaint()
                    onVisibleChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        c.lineWidth = 3.5; c.lineCap = "round";
                        c.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
                        c.beginPath(); c.arc(18, 18, 14, 0, Math.PI * 2); c.stroke();
                        c.strokeStyle = Theme.violet;
                        c.beginPath(); c.arc(18, 18, 14, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.03, p)); c.stroke();
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: card.running ? Packages.pct : "…"
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 10; font.bold: true
                }
            }
            PillBtn {
                visible: card.job === null && !card.inst
                label: card.err ? "Retry" : "Get"
                primary: true
                onClicked: Packages.enqueue(card.app.pkg, card.app.name, "install", "", card.app.pkgs ?? (card.app.aur ? ["aur/" + card.app.pkg] : null))
            }
            PillBtn {
                visible: card.job === null && card.inst && !card.app.tool && !card.isBundle
                label: "Open"
                primary: true
                tint: "#34C77B"
                onClicked: win.openApp(card.app)
            }
            PillBtn {
                visible: card.job === null && card.inst && (cm.hovered || card.app.tool || card.isBundle)
                label: "Remove"
                onClicked: Packages.enqueue(card.app.pkg, card.app.name, "remove", "", card.app.pkgs)
            }
        }
    }
}
