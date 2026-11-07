import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Trình cài đặt Islet: Chào mừng → Ổ đĩa → Tài khoản → Múi giờ → Xác nhận → Đang cài → Xong.
// Mở: mục "Cài đặt Islet" trong lưới Ứng dụng, hoặc `qs ipc call installer open`.
// Phần việc thật do /usr/local/bin/islet-install làm (chạy qua sudo).
PanelWindow {
    id: win

    implicitWidth: 780
    implicitHeight: 540
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "islet-installer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool open: Ui.installerOpen
    visible: open || panel.opacity > 0.01
    mask: Region { item: panel }

    // ---------------- dữ liệu ----------------
    property int step: 0          // 0 chào · 1 ổ · 2 tài khoản · 3 giờ · 4 xác nhận · 5 đang cài · 6 xong · 7 lỗi
    readonly property var stepNames: ["Welcome", "Disk", "Account", "Time zone", "Confirm"]

    property var disks: []
    property string disk: ""
    property string fullName: ""
    property string userName: ""
    property bool userEdited: false
    property string password: ""
    property string password2: ""
    property string hostName: "islet"
    property bool autologin: true
    property bool uefi: false
    property bool btrfs: true      // Btrfs + snapper: điểm khôi phục tự động trước mỗi lần cập nhật (chỉ máy UEFI)
    Process { running: true; command: ["test", "-d", "/sys/firmware/efi"]; onExited: code => win.uefi = code === 0 }
    property string tz: "Asia/Ho_Chi_Minh"

    property int progress: 0
    property string progressText: ""
    property var logLines: []
    property string errorText: ""
    property bool armed: false

    readonly property var diskInfo: disks.find(d => d.path === disk) ?? null

    onOpenChanged: if (open) { if (step >= 5 && step !== 7) return; step = step === 7 ? 4 : step; scanDisks(); panel.forceActiveFocus(); }

    function bytes(b) {
        if (b >= 1e12) return (b / 1e12).toFixed(1) + " TB";
        return Math.round(b / 1e9) + " GB";
    }
    function slug(s) {
        return s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d")
            .replace(/[^a-z0-9]+/g, "").slice(0, 24);
    }
    onFullNameChanged: if (!userEdited) userName = slug(fullName.split(" ").slice(-1)[0] || fullName)

    readonly property string accountError: {
        if (fullName.trim() === "") return "Enter your name";
        if (!/^[a-z_][a-z0-9_-]{0,31}$/.test(userName)) return "Username may only contain lowercase letters, numbers, - and _";
        if (password.length < 4) return "Password must be at least 4 characters";
        if (password !== password2) return "Passwords don't match";
        if (!/^[a-zA-Z0-9-]{1,63}$/.test(hostName)) return "Computer name may only contain letters, numbers and -";
        return "";
    }
    readonly property bool canNext: step === 0 || (step === 1 && disk !== "" && (diskInfo?.size ?? 0) >= 10e9)
        || (step === 2 && accountError === "") || step === 3

    function next() { if (canNext && step < 4) { step++; armed = false; } }
    function back() { if (step > 0 && step <= 4) { step--; armed = false; } }

    // ---------------- quét ổ đĩa ----------------
    function scanDisks() { scan.running = true; }
    Process {
        id: scan
        command: ["sh", "-c", "boot=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null | xargs -r lsblk -no PKNAME 2>/dev/null); "
            + "lsblk -J -b -d -o PATH,NAME,SIZE,MODEL,TRAN,TYPE,RM | python3 -c \"import json,sys; d=json.load(sys.stdin)['blockdevices']; "
            + "b=sys.argv[1]; print(json.dumps([x for x in d if x['type']=='disk' and x['name']!=b and not x['name'].startswith(('zram','loop','sr'))]))\" \"$boot\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.disks = JSON.parse(text); } catch (e) { win.disks = []; }
                if (win.disks.length === 1) win.disk = win.disks[0].path;
            }
        }
    }

    // ---------------- cài ----------------
    function install() {
        step = 5;
        progress = 0;
        progressText = "Preparing…";
        logLines = [];
        errorText = "";
        runner.running = true;
    }
    Process {
        id: runner
        stdinEnabled: true
        command: ["sudo", "-n", "/usr/local/bin/islet-install", win.disk, win.userName, Qt.btoa(unescape(encodeURIComponent(win.fullName))),
                  win.hostName, win.tz, win.autologin ? "1" : "0", win.uefi && win.btrfs ? "btrfs" : "ext4"]
        onStarted: { write(win.password + "\n"); }
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("PROGRESS ")) {
                    const sp = line.indexOf(" ", 9);
                    win.progress = parseInt(line.slice(9, sp));
                    win.progressText = line.slice(sp + 1);
                } else if (line.startsWith("ERROR ")) {
                    win.errorText = line.slice(6);
                } else if (line === "DONE") {
                    win.progress = 100;
                    win.step = 6;
                } else {
                    win.logLines = win.logLines.concat([line.replace(/^LOG /, "")]).slice(-200);
                }
            }
        }
        stderr: SplitParser { onRead: line => win.logLines = win.logLines.concat([line]).slice(-200) }
        onExited: (code, status) => {
            if (win.step !== 6) {
                if (!win.errorText) win.errorText = "Installer stopped (code " + code + ")";
                win.step = 7;
            }
        }
    }

    // ================= giao diện =================
    Glass {
        id: panel
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0.05, 0.05, 0.09, 0.9)

        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.002 } }

        Keys.onEscapePressed: if (win.step !== 5) Ui.installerOpen = false

        // ---- đầu: các bước ----
        Row {
            x: 28
            y: 24
            spacing: 6
            visible: win.step <= 4
            Repeater {
                model: win.stepNames
                Row {
                    required property string modelData
                    required property int index
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 11
                        color: index < win.step ? Theme.violet : index === win.step ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Icon {
                            anchors.centerIn: parent
                            visible: index < win.step
                            name: "check"
                            size: 13
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: index >= win.step
                            text: index + 1
                            color: index === win.step ? "#000000" : "#FFFFFF"
                            font.family: Theme.font; font.pixelSize: 11; font.bold: true
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: index === win.step ? "#FFFFFF" : "#8E8E93"
                        font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: index < win.stepNames.length - 1
                        width: 18; height: 1.5; radius: 1
                        color: Qt.rgba(1, 1, 1, 0.15)
                    }
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 22
            y: 20
            visible: win.step !== 5
            width: 30; height: 30; radius: 15
            color: xm.containsMouse ? "#FF5F57" : Qt.rgba(1, 1, 1, 0.08)
            Icon { anchors.centerIn: parent; name: "close"; size: 14 }
            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Ui.installerOpen = false }
        }

        // ---- nội dung ----
        Item {
            id: page
            x: 36
            y: 74
            width: parent.width - 72
            height: parent.height - y - 84

            // ① Chào mừng
            Column {
                visible: win.step === 0
                anchors.centerIn: parent
                spacing: 14
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 108; height: 108
                    sourceSize: Qt.size(216, 216)
                    source: Theme.appIcon("islet")
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Install Islet on this computer"
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 26; font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 460
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                    text: "You're running the live session — everything is lost when you power off. Install Islet to keep your apps, files and settings."
                    color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 13
                }
            }

            // ② Ổ đĩa
            Column {
                visible: win.step === 1
                width: parent.width
                spacing: 10
                Title { text: "Choose a disk" }
                Sub { text: "Islet will use the whole disk. At least 10 GB required." }
                Repeater {
                    model: win.disks
                    Rectangle {
                        id: dcard
                        required property var modelData
                        readonly property bool sel: win.disk === modelData.path
                        readonly property bool small: modelData.size < 10e9
                        width: page.width
                        height: 64
                        radius: 18
                        color: sel ? Theme.tint(0.22) : dm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: sel ? 1.5 : 1
                        border.color: sel ? Theme.violet : Qt.rgba(1, 1, 1, 0.06)
                        opacity: small ? 0.45 : 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            width: 38; height: 38; radius: 11
                            gradient: Gradient { GradientStop { position: 0; color: "#7A8396" } GradientStop { position: 1; color: "#3B4253" } }
                            Icon { anchors.centerIn: parent; name: "disk"; size: 20 }
                        }
                        Column {
                            x: 66; anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: (dcard.modelData.model || "Disk") + "  ·  " + win.bytes(dcard.modelData.size)
                                color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                            }
                            Text {
                                text: dcard.modelData.path + (dcard.modelData.tran ? "  ·  " + dcard.modelData.tran.toUpperCase() : "")
                                    + (dcard.small ? "  ·  too small" : "")
                                color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 20; height: 20; radius: 10
                            color: dcard.sel ? Theme.violet : "transparent"
                            border.width: dcard.sel ? 0 : 1.5; border.color: Qt.rgba(1, 1, 1, 0.3)
                            Icon { anchors.centerIn: parent; visible: dcard.sel; name: "check"; size: 13 }
                        }
                        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; enabled: !dcard.small; cursorShape: Qt.PointingHandCursor; onClicked: win.disk = dcard.modelData.path }
                    }
                }
                Sub { visible: win.disks.length === 0; text: "No disks found to install on." }
                Rectangle {
                    visible: win.disk !== ""
                    width: page.width; height: 40; radius: 14
                    color: Qt.rgba(1, 0.37, 0.34, 0.14)
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "warning"; size: 16; color: "#FF8A8A" }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "All data on " + win.disk + " will be erased."
                            color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                }
                Row {
                    visible: win.uefi
                    spacing: 12
                    topPadding: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 26; radius: 13
                        color: win.btrfs ? Theme.violet : Qt.rgba(1, 1, 1, 0.15)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Rectangle {
                            width: 20; height: 20; radius: 10; y: 3
                            x: win.btrfs ? 21 : 3
                            color: "#FFFFFF"
                            Behavior on x { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.1 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.btrfs = !win.btrfs }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Btrfs with snapshots"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: "Saves a restore point before every update — roll back from Settings › Snapshots"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                    }
                }
            }

            // ③ Tài khoản
            Column {
                visible: win.step === 2
                width: parent.width
                spacing: 10
                Title { text: "Create your account" }
                Row {
                    spacing: 12
                    Field { width: (page.width - 12) / 2; label: "Your name"; text: win.fullName; onEdited: t => win.fullName = t; focusOnShow: true }
                    Field { width: (page.width - 12) / 2; label: "Username"; text: win.userName; onEdited: t => { win.userName = t; win.userEdited = true; } }
                }
                Row {
                    spacing: 12
                    Field { width: (page.width - 12) / 2; label: "Password"; secret: true; text: win.password; onEdited: t => win.password = t }
                    Field { width: (page.width - 12) / 2; label: "Confirm password"; secret: true; text: win.password2; onEdited: t => win.password2 = t }
                }
                Field { width: (page.width - 12) / 2; label: "Computer name"; text: win.hostName; onEdited: t => win.hostName = t }
                Row {
                    spacing: 12
                    topPadding: 4
                    Rectangle {
                        width: 44; height: 26; radius: 13
                        color: win.autologin ? Theme.violet : Qt.rgba(1, 1, 1, 0.15)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Rectangle {
                            width: 20; height: 20; radius: 10; y: 3
                            x: win.autologin ? 21 : 3
                            color: "#FFFFFF"
                            Behavior on x { SpringAnimation { spring: 5; damping: 0.35; epsilon: 0.1 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.autologin = !win.autologin }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Log in automatically"
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13
                    }
                }
                Text {
                    text: win.accountError
                    color: "#FFB547"; font.family: Theme.font; font.pixelSize: 12
                    visible: (win.fullName !== "" || win.password !== "") && win.accountError !== ""
                }
            }

            // ④ Múi giờ
            Column {
                visible: win.step === 3
                width: parent.width
                spacing: 10
                Title { text: "Time zone" }
                Grid {
                    columns: 3
                    spacing: 8
                    Repeater {
                        model: [["Asia/Ho_Chi_Minh", "Vietnam"], ["Asia/Bangkok", "Thailand"], ["Asia/Singapore", "Singapore"],
                                ["Asia/Tokyo", "Japan"], ["Asia/Seoul", "South Korea"], ["Asia/Shanghai", "China"],
                                ["Australia/Sydney", "Australia (Sydney)"], ["Europe/London", "Anh"], ["Europe/Paris", "France"],
                                ["Europe/Berlin", "Germany"], ["America/New_York", "USA (New York)"], ["America/Los_Angeles", "USA (Los Angeles)"],
                                ["UTC", "UTC"]]
                        Rectangle {
                            required property var modelData
                            readonly property bool sel: win.tz === modelData[0]
                            width: (page.width - 16) / 3
                            height: 48
                            radius: 14
                            color: sel ? Theme.tint(0.22) : tzm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                            border.width: sel ? 1.5 : 0
                            border.color: Theme.violet
                            Column {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData[1]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text { text: modelData[0]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 10 }
                            }
                            MouseArea { id: tzm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.tz = parent.modelData[0] }
                        }
                    }
                }
            }

            // ⑤ Xác nhận
            Column {
                visible: win.step === 4
                width: parent.width
                spacing: 10
                Title { text: "Ready to install" }
                Repeater {
                    model: [
                        ["Disk", win.diskInfo ? (win.diskInfo.model || win.disk) + " · " + win.bytes(win.diskInfo.size) + " (" + win.disk + ")" : ""],
                        ["File system", win.uefi && win.btrfs ? "Btrfs with snapshots" : "ext4"],
                        ["Account", win.fullName + " (" + win.userName + ")" + (win.autologin ? " · auto login" : "")],
                        ["Computer name", win.hostName],
                        ["Time zone", win.tz]
                    ]
                    Rectangle {
                        required property var modelData
                        width: page.width; height: 46; radius: 14
                        color: Qt.rgba(1, 1, 1, 0.05)
                        Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                        Text { x: 130; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                }
                Rectangle {
                    width: page.width; height: 40; radius: 14
                    color: Qt.rgba(1, 0.37, 0.34, 0.14)
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: "warning"; size: 16; color: "#FF8A8A" }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Click Install and " + win.disk + " will be erased. This cannot be undone."
                            color: "#FF8A8A"; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                }
            }

            // ⑥ Đang cài / Xong / Lỗi
            Column {
                visible: win.step >= 5
                anchors.centerIn: parent
                width: parent.width
                spacing: 16
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 84; height: 84
                    sourceSize: Qt.size(168, 168)
                    source: Theme.appIcon("islet")
                    SequentialAnimation on scale {
                        running: win.step === 5
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.06; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.step === 5 ? "Installing Islet…" : win.step === 6 ? "All done!" : "Installation failed"
                    color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 22; font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: win.step === 5 ? win.progressText
                        : win.step === 6 ? "Remove the installation media and restart to start using Islet."
                        : win.errorText
                    color: win.step === 7 ? "#FF8A8A" : "#AEAEB2"; font.family: Theme.font; font.pixelSize: 13
                }
                // thanh tiến trình
                Rectangle {
                    visible: win.step !== 7
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 460; height: 10; radius: 5
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Rectangle {
                        height: parent.height; radius: 5
                        width: parent.width * win.progress / 100
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#4BE3E8" }
                            GradientStop { position: 0.5; color: Theme.violet }
                            GradientStop { position: 1; color: "#FF6B97" }
                        }
                    }
                }
                Text {
                    visible: win.step === 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.progress + "%"
                    color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12; font.features: ({ "tnum": 1 })
                }
                // nhật ký (khi lỗi)
                Rectangle {
                    visible: win.step === 7
                    width: parent.width; height: 120; radius: 12
                    color: Qt.rgba(0, 0, 0, 0.35)
                    clip: true
                    Text {
                        x: 12; y: 10; width: parent.width - 24
                        text: win.logLines.slice(-7).join("\n")
                        color: "#AEAEB2"; font.family: Theme.mono; font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ---- chân: nút ----
        Item {
            x: 28
            width: parent.width - 56
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            height: 40
            visible: win.step !== 5

            Btn {
                visible: win.step > 0 && win.step <= 4
                anchors.left: parent.left
                label: "Revert"
                onClicked: win.back()
            }
            Btn {
                anchors.right: parent.right
                primary: true
                danger: win.step === 4
                enabled_: win.step === 4 || win.step >= 6 || win.canNext
                label: win.step === 0 ? "Start"
                    : win.step < 4 ? "Next"
                    : win.step === 4 ? (win.armed ? "Click again to install" : "Install")
                    : win.step === 6 ? "Restart"
                    : "Retry"
                onClicked: {
                    if (win.step < 4) win.next();
                    else if (win.step === 4) { if (win.armed) win.install(); else { win.armed = true; disarm.restart(); } }
                    else if (win.step === 6) Quickshell.execDetached(["systemctl", "reboot"]);
                    else win.step = 4;
                }
            }
        }
        Timer { id: disarm; interval: 3500; onTriggered: win.armed = false }
    }

    // ---------------- thành phần ----------------
    component Title: Text { color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Bold; bottomPadding: 2 }
    component Sub: Text { color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12; bottomPadding: 4 }

    component Field: Column {
        id: f
        property string label: ""
        property string text: ""
        property bool secret: false
        property bool focusOnShow: false
        signal edited(string t)
        spacing: 5
        onVisibleChanged: if (visible && focusOnShow) inp.forceActiveFocus()
        Text { text: f.label; color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        Rectangle {
            width: f.width; height: 40; radius: 12
            color: Qt.rgba(1, 1, 1, inp.activeFocus ? 0.12 : 0.06)
            border.width: 1
            border.color: inp.activeFocus ? Theme.violet : Qt.rgba(1, 1, 1, 0.08)
            TextInput {
                id: inp
                x: 12; width: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                text: f.text
                echoMode: f.secret ? TextInput.Password : TextInput.Normal
                color: "#FFFFFF"; selectionColor: Theme.violet
                font.family: Theme.font; font.pixelSize: 13
                clip: true
                onTextEdited: f.edited(text)
                Keys.onReturnPressed: win.next()
                KeyNavigation.tab: null
            }
            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: inp.forceActiveFocus() }
        }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool primary: false
        property bool danger: false
        property bool enabled_: true
        signal clicked()
        width: bl.implicitWidth + 40
        height: 40
        radius: 20
        opacity: enabled_ ? 1 : 0.4
        color: !primary ? (bm.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            : danger ? (win.armed ? "#FF5F57" : bm.containsMouse ? "#FF7A72" : "#FF5F57")
            : bm.containsMouse ? "#A99CFF" : Theme.violet
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: bm.pressed ? 0.95 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.003 } }
        Text { id: bl; anchors.centerIn: parent; text: b.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Bold }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; enabled: b.enabled_; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
