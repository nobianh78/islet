pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Chọn trình phát nhạc đang hoạt động qua MPRIS (Spotify, Firefox, mpv, ...).
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // Ưu tiên trình đang phát; nếu không có thì lấy trình vừa phát gần nhất.
    property MprisPlayer last: null
    readonly property MprisPlayer active: {
        const list = root.players;
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) return list[i];
        if (root.last && list.indexOf(root.last) >= 0) return root.last;
        return list.length > 0 ? list[0] : null;
    }
    onActiveChanged: if (active && active.isPlaying) last = active

    readonly property bool hasPlayer: active !== null && (active.trackTitle ?? "") !== ""
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle || "Untitled"
    readonly property string artist: active?.trackArtist || active?.identity || ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    readonly property real length: active?.length ?? 0
    readonly property real position: (active?.position ?? 0) + fix
    readonly property bool canSeek: (active?.canSeek ?? false) && (active?.positionSupported ?? false)

    // MPRIS không tự báo vị trí mới, nên phải yêu cầu cập nhật khi cần.
    property bool wantPosition: false

    // Quickshell chỉ ước lượng vị trí; trình nào không báo "Seeked" khi tua (Firefox, Spotify…) thì lệch mãi.
    // Như bản Dynamic Island cho GNOME: khi đang xem vị trí, mỗi giây hỏi lại trình phát qua D-Bus,
    // lệch quá 0,35 s thì bù vào (lời bài hát, thanh tiến trình theo kịp khi tua).
    property real fix: 0
    readonly property string busName: active?.dbusName ?? ""
    onBusNameChanged: fix = 0
    onTitleChanged: fix = 0
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.wantPosition && root.busName !== ""
        onTriggered: if (!posProc.running) { posProc.sentAt = root.position - root.fix; posProc.running = true; }
    }
    Process {
        id: posProc
        property real sentAt: 0
        command: ["busctl", "--user", "get-property", root.busName, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^x\s+(-?\d+)/);
                if (!m) return;
                const real = Number(m[1]) / 1e6;
                const est = (posProc.sentAt + (root.active?.position ?? 0)) / 2;   // giữa lúc hỏi và lúc nhận
                const d = real - est;
                root.fix = Math.abs(d) > 0.35 ? d : 0;
            }
        }
    }
    FrameAnimation {
        running: root.wantPosition && root.playing
        onTriggered: root.active?.positionChanged()
    }

    // Màu chủ đạo của ảnh bìa (để nhuộm island và sóng nhạc).
    // null khi không có ảnh.
    readonly property var accent: {
        const cs = quant.colors;
        if (!artUrl || !cs || cs.length === 0) return null;
        // chọn màu rực nhất, tránh màu quá tối / quá nhạt
        let best = cs[0], score = -1;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            const mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b);
            const sat = mx - mn, light = (mx + mn) / 2;
            const sc = sat * (1 - Math.abs(light - 0.55) * 1.4);
            if (sc > score) { score = sc; best = c; }
        }
        return best;
    }
    ColorQuantizer {
        id: quant
        source: root.artUrl
        depth: 3
        rescaleSize: 64
    }

    function toggle() { if (active?.canTogglePlaying) active.togglePlaying(); }
    function next() { if (active?.canGoNext) active.next(); }
    function previous() { if (active?.canGoPrevious) active.previous(); }
    function seekTo(fraction) {
        if (!canSeek || length <= 0) return;
        fix = 0;
        active.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
