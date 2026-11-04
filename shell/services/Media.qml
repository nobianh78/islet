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
    readonly property string title: active?.trackTitle || "Không có tiêu đề"
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
