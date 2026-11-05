pragma Singleton
import QtQuick
import Quickshell
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
    readonly property real position: active?.position ?? 0
    readonly property bool canSeek: (active?.canSeek ?? false) && (active?.positionSupported ?? false)

    // MPRIS không tự báo vị trí mới, nên phải yêu cầu cập nhật khi cần.
    property bool wantPosition: false
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
        active.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
