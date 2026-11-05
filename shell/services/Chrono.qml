pragma Singleton
import QtQuick
import Quickshell

// Đồng hồ trên island: bấm giờ · đếm ngược · Pomodoro (25′ tập trung / 5′ nghỉ, 4 lượt thì nghỉ 15′).
Singleton {
    id: root

    property string mode: ""            // "" | stopwatch | countdown | pomodoro
    property bool running: false
    property real startedAt: 0          // bấm giờ: mốc bắt đầu (đã trừ thời gian tạm dừng)
    property real endsAt: 0             // đếm ngược: mốc kết thúc
    property real frozen: 0             // ms còn lại / đã chạy lúc tạm dừng
    property real total: 0              // ms của lượt đếm ngược hiện tại
    property string phase: ""           // Pomodoro: "Focus" | "Break" | "Long break"
    property int round: 0
    readonly property bool active: mode !== ""

    property real now: Date.now()
    Timer { interval: 250; running: root.active && root.running; repeat: true; triggeredOnStart: true; onTriggered: { root.now = Date.now(); root.check(); } }

    readonly property real elapsed: mode === "stopwatch" ? (running ? now - startedAt : frozen) : 0
    readonly property real remaining: mode === "countdown" || mode === "pomodoro" ? Math.max(0, running ? endsAt - now : frozen) : 0
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    readonly property string text: fmt(mode === "stopwatch" ? elapsed : remaining)

    signal done(string title, string body)

    function fmt(ms) {
        const s = Math.ceil(ms / 1000) | 0, h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
        const p = x => (x < 10 ? "0" : "") + x;
        return (h ? h + ":" + p(m) : m) + ":" + p(ss);
    }

    function stopwatch() { mode = "stopwatch"; frozen = 0; startedAt = Date.now(); running = true; phase = ""; }
    function countdown(min) { mode = "countdown"; phase = ""; startCount(min * 60000); }
    function pomodoro() { mode = "pomodoro"; round = 1; phase = "Focus"; startCount(25 * 60000); }
    function startCount(ms) { total = ms; endsAt = Date.now() + ms; running = true; now = Date.now(); }
    function toggle() {
        if (!active) return;
        if (running) { frozen = mode === "stopwatch" ? Date.now() - startedAt : Math.max(0, endsAt - Date.now()); running = false; }
        else { if (mode === "stopwatch") startedAt = Date.now() - frozen; else endsAt = Date.now() + frozen; running = true; }
    }
    function addMinute() { if (mode === "countdown" || mode === "pomodoro") { if (running) endsAt += 60000; else frozen += 60000; total += 60000; } }
    function stop() { mode = ""; running = false; phase = ""; round = 0; }

    function chime() { Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/complete.oga"]); }
    function check() {
        if (!running || (mode !== "countdown" && mode !== "pomodoro") || Date.now() < endsAt) return;
        chime();
        if (mode === "countdown") {
            done("Time's up", fmt(total) + " timer finished");
            stop();
            return;
        }
        // Pomodoro: chuyển lượt
        if (phase === "Focus") {
            const long = round % 4 === 0;
            phase = long ? "Long break" : "Break";
            done("Focus session done", long ? "Take a long break · 15 min" : "Take a short break · 5 min");
            startCount((long ? 15 : 5) * 60000);
        } else {
            round += 1;
            phase = "Focus";
            done("Break's over", "Focus round " + round + " · 25 min");
            startCount(25 * 60000);
        }
    }
}
