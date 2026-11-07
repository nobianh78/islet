import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../theme"
import "../services"
import "../common"
import "../island"
import "../wallpaper"

// Màn hình khoá Islet (ext-session-lock: khoá thật, app khác không vẽ đè được).
//   Khoá: Super+L, menu logo mèo → Lock Screen, trước khi ngủ, và ngay khi bật máy (Prefs.lockOnBoot).
//   Mở: mật khẩu tài khoản (PAM "login").
//
// Ba cách vào / ra, nối liền với phần trước và sau nó:
//   · Từ boot   — khung đầu giống hệt khung cuối của Plymouth (theme/plymouth/islet): nền mực, mèo 168px
//                 ở giữa, chữ Islet, viên tiến trình đầy. Rồi viên tiến trình thu lại, mèo bay xuống
//                 làm ảnh đại diện, hình nền hiện ra sau lớp kính mờ, đồng hồ rơi xuống, ô mật khẩu nảy lên.
//   · Super+L   — hình nền mờ dần thành kính, mèo nảy vào chỗ ảnh đại diện.
//   · Mở khoá   — chữ và ô tan đi, kính mờ trong dần đúng thành hình nền của màn hình nền (cùng
//                 đồng hồ trôi Drift) → bỏ khoá không thấy "nhảy"; thanh trên và dock tự trượt vào.
Scope {
    id: root

    // ---- trạng thái dùng chung cho mọi màn hình ----
    property string password: ""
    property bool checking: false
    property string error: ""
    property int fails: 0
    property bool leaving: false        // đang chạy hiệu ứng mở khoá
    property bool hasFace: false        // có ~/.face không (xem lại mỗi lần khoá)
    Process { id: faceCheck; running: true; command: ["test", "-f", Quickshell.env("HOME") + "/.face"]; onExited: code => root.hasFace = code === 0 }
    property bool live: false           // bản chạy thử (tài khoản không mật khẩu)
    signal shake()

    readonly property string user: Quickshell.env("USER") || "islet"

    Process {
        running: true
        command: ["test", "-d", "/run/archiso"]
        onExited: code => root.live = code === 0
    }

    Component.onCompleted: {
        if (Ui.fromBoot && Prefs.lockOnBoot) {
            Ui.bootIntro = true;
            Ui.locked = true;
            lock.locked = true;
        }
    }

    function submit() {
        if (checking || leaving) return;
        error = "";
        checking = true;
        if (!pam.start()) { checking = false; error = "Couldn't start PAM"; }
    }

    PamContext {
        id: pam
        config: "login"
        user: root.user
        onPamMessage: {
            if (responseRequired) respond(root.password);
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.fails = 0;
                root.error = "";
                root.leaving = true;
                Sounds.play("unlock");
                finish.restart();
            } else {
                root.fails += 1;
                root.error = root.fails >= 3 ? "Wrong password · take your time" : "Wrong password";
                root.password = "";
                root.shake();
            }
        }
        onError: err => { root.checking = false; root.error = "Authentication error"; root.password = ""; root.shake(); }
    }

    // đợi kính trong hẳn rồi mới bỏ khoá thật
    Timer {
        id: finish
        interval: 640
        onTriggered: {
            lock.locked = false;
            Ui.locked = false;
            Ui.bootIntro = false;
            root.leaving = false;
            root.password = "";
        }
    }

    Connections {
        target: Ui
        function onLockedChanged() {
            if (Ui.locked && !lock.locked) { root.password = ""; root.error = ""; root.leaving = false; faceCheck.running = true; lock.locked = true; Sounds.play("lock"); }
        }
    }

    WlSessionLock {
        id: lock
        locked: false

        WlSessionLockSurface {
            id: surf
            color: "#0A0A14"

            readonly property bool boot: Ui.bootIntro
            readonly property real cx: width / 2
            readonly property real cy: height / 2

            // ---------- các "nhịp" của màn chào (0 → 1), chạy một lần khi mặt khoá hiện ----------
            property real bootUi: boot ? 1 : 0     // chữ Islet + viên tiến trình (chỉ từ boot)
            property real fly: 0                    // mèo: tư thế boot (0) → ảnh đại diện (1)
            property real wall: 0                   // hình nền sau kính
            property real clockIn: 0
            property real authIn: 0
            property real clear: 0                  // mở khoá: kính trong dần (1 = đúng hình nền)

            SequentialAnimation {
                id: intro
                running: true
                PauseAnimation { duration: surf.boot ? 140 : 0 }
                ParallelAnimation {
                    NumberAnimation { target: surf; property: "bootUi"; to: 0; duration: 380; easing.type: Easing.InCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: surf.boot ? 160 : 0 }
                        NumberAnimation { target: surf; property: "fly"; to: 1; duration: surf.boot ? 1050 : 620; easing.type: Easing.OutBack; easing.overshoot: surf.boot ? 1.15 : 1.6 }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: surf.boot ? 260 : 0 }
                        NumberAnimation { target: surf; property: "wall"; to: 1; duration: surf.boot ? 1100 : 520; easing.type: Easing.InOutCubic }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: surf.boot ? 620 : 120 }
                        NumberAnimation { target: surf; property: "clockIn"; to: 1; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: surf.boot ? 900 : 220 }
                        NumberAnimation { target: surf; property: "authIn"; to: 1; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                }
            }
            // mở khoá
            Connections {
                target: root
                function onLeavingChanged() { if (root.leaving) outro.restart(); }
            }
            ParallelAnimation {
                id: outro
                NumberAnimation { target: surf; property: "authIn"; to: 0; duration: 300; easing.type: Easing.InCubic }
                NumberAnimation { target: surf; property: "clockIn"; to: 0; duration: 360; easing.type: Easing.InCubic }
                NumberAnimation { target: surf; property: "clear"; to: 1; duration: 600; easing.type: Easing.InOutCubic }
            }

            // ---------- nền: hình nền sau lớp kính mờ ----------
            Item {
                anchors.fill: parent
                opacity: surf.wall
                scale: 1 + 0.06 * (1 - surf.wall)

                Backdrop {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: 0.7 * (1 - surf.clear)
                        brightness: -0.12 * (1 - surf.clear)
                        saturation: 0.15 * (1 - surf.clear)
                    }
                }
                Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.28 * (1 - surf.clear)) }
            }

            // ---------- tàn dư màn hình khởi động: chữ Islet + viên tiến trình đầy ----------
            Text {
                visible: surf.bootUi > 0.001
                anchors.horizontalCenter: parent.horizontalCenter
                y: surf.cy - 124 + 168 + 14 - 2
                text: "Islet"
                color: Qt.rgba(1, 1, 1, 0.92)
                opacity: surf.bootUi
                font.family: Theme.font
                font.pixelSize: 30
                font.weight: Font.Bold
            }
            Rectangle {
                visible: surf.bootUi > 0.001
                x: surf.cx - width / 2
                y: surf.cy - 124 + 168 + 14 + 32 + 30
                width: 180 * surf.bootUi
                height: 8
                radius: 4
                opacity: surf.bootUi
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#8B7CFF" }
                    GradientStop { position: 1; color: "#FF6B97" }
                }
            }

            // ---------- đồng hồ ----------
            Column {
                id: clockCol
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.13 - 60 * (1 - surf.clockIn)
                opacity: Math.min(1, surf.clockIn * 1.4)
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.dateLong
                    color: Qt.rgba(1, 1, 1, 0.78)
                    font.family: Theme.font
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }
                RollingClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.time
                    pixelSize: Math.round(Math.min(surf.width, 1600) * 0.105)
                    weight: Font.Bold
                    colonColor: Theme.accent
                }
            }

            // ---------- đang phát ----------
            Rectangle {
                id: media
                readonly property var player: Media.hasPlayer ? Media.active : null
                visible: player !== null
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: clockCol.bottom
                anchors.topMargin: 18
                width: 340
                height: 64
                radius: 22
                color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                opacity: surf.clockIn

                Rectangle {
                    id: cover
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 44; height: 44; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.1)
                    clip: true
                    Image { anchors.fill: parent; source: media.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                }
                Column {
                    anchors.left: cover.right; anchors.leftMargin: 12
                    anchors.right: playBtn.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; elide: Text.ElideRight; text: media.player?.trackTitle ?? ""; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { width: parent.width; elide: Text.ElideRight; text: media.player?.trackArtist ?? ""; color: Qt.rgba(1, 1, 1, 0.6); font.family: Theme.font; font.pixelSize: 11 }
                }
                Rectangle {
                    id: playBtn
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 18
                    color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                    Icon { anchors.centerIn: parent; name: media.player?.isPlaying ? "pause" : "play"; size: 16 }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: media.player?.togglePlaying() }
                }
            }

            // ---------- ảnh đại diện: vòng sáng (con mèo bay vào giữa vòng) ----------
            readonly property real avatarCY: height * 0.6 + 46
            Rectangle {
                id: halo
                anchors.horizontalCenter: parent.horizontalCenter
                y: surf.avatarCY - 46
                width: 92; height: 92; radius: 46
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 2
                border.color: root.error ? Theme.red : Theme.accent
                Behavior on border.color { ColorAnimation { duration: 200 } }
                opacity: surf.authIn * (root.checking ? 1 : breath)
                scale: (0.6 + 0.4 * surf.authIn) * (root.checking ? pulse : 1)
                property real breath: 1
                property real pulse: 1
                SequentialAnimation on breath {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on pulse {
                    loops: Animation.Infinite
                    running: root.checking
                    NumberAnimation { to: 1.1; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutSine }
                }
            }

            // quầng sáng tím sau lưng mèo (giống Plymouth), co lại khi mèo bay xuống
            Rectangle {
                readonly property real size: 420 - 290 * surf.fly
                x: hero.x + hero.width / 2 - size / 2
                y: hero.y + hero.height * 0.5 + 8 * (1 - surf.fly) - size / 2
                width: size; height: size; radius: size / 2
                opacity: 0.6 * (1 - surf.fly * 0.7) * (1 - surf.clear)
                color: "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height; radius: width / 2
                    color: "#8B7CFF"           // tím thương hiệu, giống quầng sáng của Plymouth
                    opacity: 0.18
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 1 }
                    scale: 0.6
                }
            }

            // con mèo: từ giữa màn hình (tư thế cuối của Plymouth) → giữa vòng ảnh đại diện
            Image {
                id: hero
                readonly property real s0: surf.boot ? 168 : 40
                readonly property real s1: 70
                readonly property real sz: s0 + (s1 - s0) * surf.fly
                readonly property real x0: surf.cx - s0 / 2
                readonly property real y0: surf.boot ? surf.cy - 124 : surf.avatarCY - s0 / 2
                width: sz
                height: sz
                x: x0 + (surf.cx - s1 / 2 - x0) * surf.fly
                y: y0 + (surf.avatarCY - s1 / 2 - y0) * surf.fly
                sourceSize: Qt.size(336, 336)
                source: Qt.resolvedUrl("../assets/brand/cat.svg")
                opacity: (surf.boot ? 1 : Math.min(1, surf.fly * 2)) * (root.leaving ? surf.authIn : 1)
                         * (face.status === Image.Ready ? 1 - Math.max(0, surf.fly * 2 - 1) : 1)
                scale: root.leaving ? 0.85 + 0.15 * surf.authIn : 1
                smooth: true
                mipmap: true
            }

            // ảnh đại diện riêng (~/.face, chọn trong Cài đặt › Users & Account): hiện dần sau khi mèo bay vào vòng
            Rounded {
                anchors.horizontalCenter: parent.horizontalCenter
                y: surf.avatarCY - 38
                width: 76; height: 76; radius: 38
                visible: face.status === Image.Ready
                opacity: Math.max(0, surf.fly * 2 - 1) * (root.leaving ? surf.authIn : 1)
                Image {
                    id: face
                    anchors.fill: parent
                    source: root.hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                    sourceSize: Qt.size(152, 152)
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                }
            }

            // ---------- tên + mật khẩu ----------
            Column {
                id: auth
                anchors.horizontalCenter: parent.horizontalCenter
                y: surf.avatarCY + 46 + 14 + 50 * (1 - surf.authIn)
                opacity: Math.min(1, surf.authIn * 1.3)
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.user
                    color: "#FFFFFF"
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280
                    height: 46
                    radius: 23
                    color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.16 : 0.11)
                    border.width: 1
                    border.color: root.error ? Qt.rgba(1, 0.42, 0.42, 0.7) : input.activeFocus ? Theme.tint(0.7) : Qt.rgba(1, 1, 1, 0.16)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    property real dx: 0
                    transform: Translate { x: field.dx }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: field; property: "dx"; to: -14; duration: 50 }
                        NumberAnimation { target: field; property: "dx"; to: 12; duration: 70 }
                        NumberAnimation { target: field; property: "dx"; to: -8; duration: 70 }
                        NumberAnimation { target: field; property: "dx"; to: 5; duration: 70 }
                        NumberAnimation { target: field; property: "dx"; to: 0; duration: 80 }
                    }
                    Connections { target: root; function onShake() { shakeAnim.restart(); } }

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 48
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: "transparent"          // chấm vẽ riêng bên dưới
                        selectionColor: "transparent"
                        cursorVisible: false
                        cursorDelegate: Item {}
                        font.pixelSize: 14
                        focus: true
                        enabled: !root.checking && !root.leaving
                        Connections { target: root; function onPasswordChanged() { if (input.text !== root.password) input.text = root.password; } }
                        onTextChanged: { if (text !== root.password) root.password = text; if (text) root.error = ""; }
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.password = ""
                        Component.onCompleted: forceActiveFocus()
                    }

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.password.length === 0
                        text: root.checking ? "Checking…" : "Enter password"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        Repeater {
                            model: Math.min(root.password.length, 18)
                            Rectangle {
                                width: 9; height: 9; radius: 4.5
                                color: "#FFFFFF"
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { SpringAnimation { spring: 6; damping: 0.32; epsilon: 0.01 } }
                            }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36; radius: 18
                        color: root.password || root.live ? Theme.accent : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        scale: gm.pressed ? 0.9 : 1
                        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35 } }
                        Text { anchors.centerIn: parent; text: "→"; color: "#FFFFFF"; font.pixelSize: 17; font.bold: true }
                        MouseArea { id: gm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.error || (root.live ? "Live session · just press Enter"
                        : Power.present ? "Battery " + Math.round(Power.percent) + "%" + (Power.charging ? " · charging" : "")
                        : "Press Enter to unlock")
                    color: root.error ? "#FF8A8A" : Qt.rgba(1, 1, 1, 0.55)
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            // ---------- nút nguồn góc phải dưới ----------
            Row {
                anchors.right: parent.right; anchors.rightMargin: 28
                anchors.bottom: parent.bottom; anchors.bottomMargin: 26 - 20 * (1 - surf.authIn)
                spacing: 10
                opacity: surf.authIn * 0.9
                Repeater {
                    model: [
                        { icon: "sleep", cmd: ["systemctl", "suspend"] },
                        { icon: "restart", cmd: ["systemctl", "reboot"] },
                        { icon: "power", cmd: ["systemctl", "poweroff"] }
                    ]
                    Rectangle {
                        required property var modelData
                        width: 40; height: 40; radius: 20
                        color: bm.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.09)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Icon { anchors.centerIn: parent; name: parent.modelData.icon; size: 17 }
                        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(parent.modelData.cmd) }
                    }
                }
            }

            // ---------- mạng góc trái dưới ----------
            Row {
                anchors.left: parent.left; anchors.leftMargin: 28
                anchors.bottom: parent.bottom; anchors.bottomMargin: 36 - 20 * (1 - surf.authIn)
                spacing: 8
                opacity: surf.authIn * 0.75
                Icon { name: Net.icon; size: 15; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Net.label; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
