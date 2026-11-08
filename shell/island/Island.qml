import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../theme"
import "../services"
import "../common"

// Dynamic Island của Islet — chuyển từ Dynamic Island cho GNOME (lib/island.js).
//
// Kiểu "tai thỏ": treo từ mép trên màn hình. Thu gọn / OSD / toast cao đúng bằng thanh trên
// nên nằm khít trong thanh; thông báo và bản mở rộng thì thả xuống.
//
//   compact   idle  [THỨ TƯ / 4 tháng 11 ……… 20:45]                  300 × 44
//             media [ảnh  Tên bài · Ca sĩ ……… sóng nhạc]            380 × 44
//   banner    notification 420 × 70 · osd 320 × 44 · toast ~240 × 44
//   expanded  tab Bây giờ / Clipboard / Agents                      560 × (150…360)
//
// Bấm vào island → mở tab Lịch; rời chuột 420 ms → thu lại (trừ khi đang gõ ghi chú); Esc để đóng. Khung co giãn bằng lò xo vật lý
// (stiffness 300, damping 0.74), nội dung cũ mờ + thu nhỏ, nội dung mới nở ra sau 90 ms.
PanelWindow {
    id: win

    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 640
    implicitHeight: 420
    color: "transparent"
    focusable: true

    WlrLayershell.namespace: "islet-island"
    // Bấm vào island là nhận bàn phím luôn (để gõ ghi chú ngay); thu lại thì trả cho app.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.layer: WlrLayer.Overlay

    mask: Region { item: body }

    readonly property int barH: 44

    // ---------------- trạng thái ----------------
    property bool expanded: false
    property var banner: null
    property var queue: []
    property real pausedAt: 0
    property bool wasPlaying: false

    readonly property string mode: {
        if (Prefs.islandMedia && Media.hasPlayer && (Media.playing || (pausedAt > 0 && Date.now() - pausedAt < 90000)))
            return "media";
        return "idle";
    }
    readonly property string view: expanded ? "expanded" : banner ? "banner" : "compact"
    readonly property bool flush: view === "compact" || (banner && (banner.kind === "osd" || banner.kind === "toast"))

    // Kích thước đích
    readonly property real targetW: {
        if (view === "expanded") return 560;
        if (view === "banner") {
            if (banner.kind === "notification") return 420;
            if (banner.kind === "osd") return 320;
            return Math.max(200, toastMetrics.width + (banner.tile || banner.icon ? 74 : 44));
        }
        // có agent đang chạy → island nở thêm một chút để chừa chỗ cho icon agent
        return (mode === "idle" ? 300 : Lyrics.status === "ok" ? 420 : 380) + (agentActive ? 30 : 0) + (liveActive && mode === "idle" ? 40 : 0);
    }
    readonly property bool liveActive: Prefs.islandLive && (Recorder.recording || Chrono.active || CopyProgress.active || Downloads.active)
    readonly property bool agentActive: Prefs.islandAgents && Agents.sessions.some(x => x.state === "working" || x.state === "attention")
    readonly property real targetH: {
        if (view === "expanded") return Math.max(barH + 120, Math.min(420, Math.max(150, expandedView.contentHeight)));
        if (flush) return barH;
        return Math.max(70, barH + 8);
    }
    readonly property real cornerR: view === "expanded" ? 32 : flush ? 16 : 22

    TextMetrics {
        id: toastMetrics
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
        text: win.banner?.text ?? ""
    }

    Spring { id: sw; target: win.targetW }
    Spring { id: sh; target: win.targetH }

    // ---------------- banner ----------------
    Timer { id: bannerTimer; onTriggered: win.endBanner(false) }

    function pushBanner(b) {
        if (expanded) {
            if (b.kind === "notification") queue.push(b);
            return;
        }
        if (banner && b.kind === "osd") {
            if (banner.kind === "notification") queue.unshift(banner);
            banner = b;
            bannerTimer.interval = b.duration;
            bannerTimer.restart();
            return;
        }
        if (banner) { queue.push(b); return; }
        showBanner(b);
    }
    function showBanner(b) {
        banner = b;
        if (b.kind === "notification") pulse();
        bannerTimer.interval = b.duration;
        bannerTimer.restart();
    }
    function endBanner(force) {
        bannerTimer.stop();
        if (!banner) return;
        if (!force && hover.hovered && banner.kind === "notification") {
            bannerTimer.interval = 1500;
            bannerTimer.restart();
            return;
        }
        banner = null;
        nextBanner();
    }
    function nextBanner() {
        if (expanded || banner || queue.length === 0) return false;
        showBanner(queue.shift());
        return true;
    }
    function bannerClicked() {
        if (banner?.onClick) { const f = banner.onClick; endBanner(true); f(); return; }
        const n = banner?.notification;
        if (n) {
            const acts = n.actions ?? [];
            for (let i = 0; i < acts.length; i++)
                if (acts[i].identifier === "default") { acts[i].invoke(); break; }
        }
        endBanner(true);
    }

    // Dùng cho IPC / thử nghiệm: qs ipc call island test notif|volume|battery|launch
    function flash(kind, ms) {
        if (kind === "notif" || kind === "notification")
            pushBanner({ kind: "notification", title: "Welcome to Islet", body: "Dynamic Island is ready", appName: "Islet", icon: "", duration: ms || 5000 });
        else if (kind === "volume")
            pushBanner({ kind: "osd", level: Audio.volume, icon: Audio.muted ? "volume-mute" : "volume", duration: ms || 1600 });
        else if (kind === "battery")
            pushBanner({ kind: "toast", icon: "bolt", text: "Charging · " + Math.round(Power.percent) + "%", duration: ms || 2600 });
        else if (kind === "launch")
            pushBanner({ kind: "toast", tile: Ui.launchTile, icon: Ui.launchIcon, iconUrl: Ui.launchIconUrl, text: "Opening " + Ui.launchLabel, duration: ms || 1800 });
    }

    // ---------------- mở rộng / thu lại ----------------
    function expand(tab) {
        if (tab) expandedView.tab = tab;

        if (banner) {
            if (banner.kind === "notification") queue.unshift(banner);
            bannerTimer.stop();
            banner = null;
        }
        expanded = true;
        if (expandedView.tab === "calendar") focusLater.restart();
    }
    // đợi cửa sổ nhận bàn phím rồi mới đặt con trỏ vào ô ghi chú
    Timer { id: focusLater; interval: 60; onTriggered: expandedView.calendarPage.focusInput() }
    function collapse() {
        if (!expanded) return;
        expanded = false;
        expandedView.calendarPage.blurInput();
        if (Windows.hasActive) Windows.focusWin(Windows.active);
        if (queue.length) afterCollapse.restart();
    }
    Timer { id: afterCollapse; interval: 450; onTriggered: win.nextBanner() }

    Timer {
        id: collapseTimer
        interval: 420
        onTriggered: if (!hover.hovered && !expandedView.calendarPage.editing) win.collapse()
    }

    function pulse() { pulseAnim.restart(); }

    // ---------------- dịch vụ → island ----------------
    Connections {
        target: Notifs
        function onArrived(n) {
            // thông báo từ agent trong VS Code / Cursor / Antigravity → hiện thành thông báo agent
            if (Agents.fromNotification(n)) return;
            // Không làm phiền: chỉ lưu vào trung tâm thông báo (thông báo khẩn vẫn hiện)
            if ((Prefs.dnd || Ui.dndNow) && n.urgency !== NotificationUrgency.Critical) return;
            // app bị tắt thông báo (Cài đặt › Notifications): vẫn lưu ở trung tâm thông báo, không bật lên
            if ((Prefs.notifMuted || []).indexOf(n.appName || "") >= 0) return;
            if (Prefs.notifSounds) Sounds.play("notification");
            win.pushBanner({
                kind: "notification",
                notification: n,
                title: n.summary || n.appName || "",
                body: Prefs.notifPreview ? (n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : "New notification",
                appName: n.appName || "",
                icon: Notifs.iconFor(n),
                duration: 5000
            });
        }
    }
    // ---- agent lập trình: cần bạn duyệt / xong việc ----
    Connections {
        target: Agents
        function onAttention(s) {
            if (!Prefs.islandAgents) return;
            win.pushBanner({
                kind: "notification",
                title: Agents.label(s.agent) + " needs you",
                body: [Agents.project(s.cwd), s.message || "waiting for approval"].filter(x => x).join(" · "),
                appName: "Agents", icon: Agents.iconOf(s.agent), duration: 12000, agentKey: s.key,
                onClick: () => { if (!Agents.focus(s)) win.expand("agents"); }
            });
        }
        function onResolved(s) {
            if (win.banner?.agentKey === s.key) win.endBanner(true);
            win.queue = win.queue.filter(b => b.agentKey !== s.key);
        }
        function onFinished(s) {
            if (Prefs.dnd || Ui.dndNow || !Prefs.islandAgents) return;
            win.pushBanner({
                kind: "notification",
                title: Agents.label(s.agent) + " finished",
                body: [Agents.project(s.cwd), s.message].filter(x => x).join(" · "),
                appName: "Agents", icon: Agents.iconOf(s.agent), duration: 7000,
                onClick: () => { if (!Agents.focus(s)) win.expand("agents"); }
            });
        }
    }
    Connections { target: Ui; function onIslandOpenRequested(tab) { win.expand(tab); } }

    // ---- hoạt động trực tiếp: hết giờ · quay xong · tải xong · micro/camera ----
    Connections {
        target: Chrono
        function onDone(title, body) {
            Sounds.play("alarm");
            win.pushBanner({ kind: "notification", title: title, body: body, appName: "Timer", icon: "", duration: 9000,
                             onClick: () => win.expand("timer") });
        }
    }
    Connections {
        target: Recorder
        function onSaved(path) {
            win.pushBanner({ kind: "notification", title: "Recording saved", body: path.split("/").pop(), appName: "Screen recording",
                             icon: "", duration: 7000, onClick: () => Quickshell.execDetached(["xdg-open", path]) });
        }
    }
    Connections {
        target: CopyProgress
        function onFinished(name) {
            win.pushBanner({ kind: "notification", title: "Copied", body: name, appName: "Files", icon: "", duration: 5000 });
        }
    }
    Connections {
        target: Downloads
        function onFinished(path, name) {
            win.pushBanner({ kind: "notification", title: "Downloaded", body: name, appName: "Downloads", icon: "", duration: 6000,
                             onClick: () => Quickshell.execDetached(["nautilus", "--select", path]) });
        }
    }
    Connections {
        target: Privacy
        function onStarted(what, app) {
            win.pushBanner({ kind: "toast", icon: what === "camera" ? "camera" : "mic", iconColor: what === "camera" ? "#30D158" : "#FF9F0A",
                             text: app + " is using your " + what, duration: 2600 });
        }
    }

    // có bản cập nhật hệ thống mới
    Connections {
        target: Updates
        function onAvailable(n) {
            if (Prefs.dnd) return;
            const ch = Updates.changes;
            win.pushBanner({
                kind: "notification",
                title: Updates.isletCount > 0 ? "Islet update available" : n === 1 ? "1 update available" : n + " updates available",
                body: Updates.isletCount > 0 && ch.length
                    ? ch.slice(0, 2).map(c => c.subject).join(" · ") + (ch.length > 2 ? " · +" + (ch.length - 2) + " more" : "")
                    : "Click to review and update Islet",
                appName: "Updates", icon: "", duration: 8000,
                onClick: () => Ui.openSettings("updates")
            });
        }
    }
    // Time Machine
    Connections {
        target: Backup
        function onStarted(label) {
            win.pushBanner({ kind: "toast", icon: "backup", text: "Backing up to " + label + "…", duration: 2600 });
        }
        function onFinished(ok, text) {
            Sounds.play(ok ? "done" : "error");
            win.pushBanner({ kind: "notification", title: ok ? "Backup finished" : "Backup didn't finish", body: text,
                             appName: "Time Machine", icon: "", duration: 7000, onClick: () => Ui.openBackups() });
        }
    }
    // vừa khởi động vào một điểm khôi phục (chọn ở menu khởi động)
    Connections {
        target: Restore
        function onBootedIntoSnapshot(n) {
            win.pushBanner({
                kind: "notification",
                title: "Running a restore point",
                body: "Click to keep this version, or restart to go back to the current system",
                appName: "Restore", icon: "", duration: 15000,
                onClick: () => Ui.openSettings("storage")
            });
        }
    }
    // bấm một mục trong tab Clipboard → thu island để cửa sổ cũ nhận phím dán
    Connections {
        target: expandedView.clipPage
        function onPicked() { win.collapse(); }
    }
    Connections {
        target: expandedView.agentsPage
        function onPicked() { win.collapse(); }
    }
    Connections {
        target: Audio
        function onTouched() {
            win.pushBanner({ kind: "osd", level: Audio.muted ? 0 : Audio.volume, icon: Audio.muted || Audio.volume <= 0.001 ? "volume-mute" : "volume", duration: 1600 });
        }
    }
    Connections {
        target: Power
        function onPlugged() { win.flash("battery"); }
    }
    Connections {
        target: Calendar
        function onRemind(n) {
            win.pushBanner({ kind: "notification", title: n.text, body: "It's time · " + n.time, appName: "Calendar", icon: "", duration: 10000 });
        }
    }
    Connections {
        target: Ui
        function onToastRequested(text, icon, kind) {
            win.pushBanner({ kind: "toast", tile: "x", icon: kind === "error" ? "store" : "store", iconUrl: icon, text: text, duration: 2400 });
        }
    }
    Connections {
        target: Ui
        function onLaunching() { win.flash("launch"); }
    }
    Connections {
        target: Media
        function onPlayingChanged() {
            if (!Media.playing && win.wasPlaying) win.pausedAt = Date.now();
            if (Media.playing) win.pausedAt = 0;
            win.wasPlaying = Media.playing;
        }
    }
    // mode "media" hết hạn 90 s sau khi tạm dừng
    Timer { interval: 5000; repeat: true; running: win.pausedAt > 0; onTriggered: win.pausedAtChanged() }

    // vị trí bài hát cần cập nhật liên tục khi đang xem tab Now, hoặc khi island thu gọn đang hiện lời
    Binding { target: Media; property: "wantPosition"; value: win.view === "expanded" || (win.view === "compact" && win.mode === "media" && Lyrics.status === "ok") }

    // ---------------- khung ----------------
    Item {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: Math.max(1, sw.value)
        height: Math.max(1, sh.value)

        transform: Scale {
            id: pulseScale
            origin.x: body.width / 2
            origin.y: 0
        }

        // bóng đổ khi thả xuống (thông báo / mở rộng)
        RectangularShadowFallback {
            anchors.fill: shape
            radius: win.cornerR
            opacity: win.flush || Prefs.islandGlass > 0 ? 0 : 0.9
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }

        Rectangle {
            id: shape
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 1 - 0.65 * Prefs.islandGlass)
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: win.cornerR
            bottomRightRadius: win.cornerR
            Behavior on bottomLeftRadius { NumberAnimation { duration: 220 } }
            Behavior on bottomRightRadius { NumberAnimation { duration: 220 } }
            clip: true

            // nhuộm màu ảnh bìa khi mở tab "Bây giờ"
            Rectangle {
                anchors.fill: parent
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
                opacity: win.view === "expanded" && expandedView.tab === "now" && Media.accent ? 1 - 0.6 * Prefs.islandGlass : 0
                Behavior on opacity { NumberAnimation { duration: 320 } }
                gradient: Gradient {
                    GradientStop { position: 0; color: Media.accent ? Qt.rgba(Media.accent.r * 0.42, Media.accent.g * 0.42, Media.accent.b * 0.42, 1) : "#000000" }
                    GradientStop { position: 1; color: "#000000" }
                }
            }

            // viền sáng + ánh sáng từ trên xuống của kính (chỉ hiện khi bật kính)
            Rectangle {
                anchors.fill: parent
                visible: Prefs.islandGlass > 0
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.38 * Prefs.islandGlass)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16 * Prefs.islandGlass) }
                    GradientStop { position: 0.5; color: "transparent" }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (win.banner) win.bannerClicked();
                    else if (Recorder.recording && !win.expanded) Recorder.stop();
                    else if (Chrono.active && !win.expanded) win.expand("timer");
                    else if (!win.expanded) win.expand("calendar");
                }
            }

            // ---- các màn ----
            Fader {
                shown: win.view === "compact"
                width: (win.mode === "idle" ? 300 : Lyrics.status === "ok" ? 420 : 380) + (win.agentActive ? 30 : 0) + (win.liveActive && win.mode === "idle" ? 40 : 0)
                height: win.barH
                CompactView {
                    id: compactView
                    anchors.fill: parent
                    mode: win.mode
                    hovered: hover.hovered
                }
            }
            Fader {
                shown: win.view === "banner"
                width: win.targetW
                height: win.view === "banner" ? win.targetH : win.barH
                BannerView {
                    anchors.fill: parent
                    banner: win.banner
                }
            }
            Fader {
                shown: win.view === "expanded"
                width: 560
                height: Math.max(150, expandedView.contentHeight)
                ExpandedView {
                    id: expandedView
                    anchors.fill: parent
                }
            }
        }

        Keys.onEscapePressed: win.collapse()
        focus: win.expanded

        HoverHandler {
            id: hover
            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                } else if (win.expanded && !expandedView.calendarPage.editing) {
                    collapseTimer.restart();
                }
            }
        }
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: pulseScale; properties: "xScale,yScale"; to: 1.06; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: pulseScale; properties: "xScale,yScale"; to: 1; duration: 520; easing.type: Easing.OutElastic; easing.amplitude: 1; easing.period: 0.4 }
    }
}
