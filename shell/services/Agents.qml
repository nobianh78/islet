pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Agent lập trình đang chạy (tab Agents + thông báo trên island).
//   · Claude Code (hooks) và Codex (notify) báo trạng thái chính xác qua `islet-agent hook` → IPC "agents event"
//   · mọi agent (kể cả Gemini CLI, OpenCode) còn được thấy qua `islet-agent ps` mỗi 2 giây;
//     agent không có hook thì đoán "đang làm" theo CPU
// state: working · attention (cần bạn duyệt) · waiting (chờ bạn nhập) · done · idle
Singleton {
    id: root

    readonly property var meta: ({
        claude:   { label: "Claude Code", icon: "claude-code" },
        codex:    { label: "Codex",       icon: "openai-codex" },
        gemini:   { label: "Gemini CLI",  icon: "gemini-cli" },
        opencode: { label: "OpenCode",    icon: "opencode" }
    })
    function label(a) { return meta[a]?.label ?? a; }
    function iconOf(a) { return Qt.resolvedUrl("../assets/store/" + (meta[a]?.icon ?? "claude-code") + ".png"); }
    function project(cwd) { const p = (cwd || "").replace(/\/+$/, ""); return p === Quickshell.env("HOME") ? "~" : p.substring(p.lastIndexOf("/") + 1) || p; }

    // { key, agent, pid, cwd, state, message, since, hooked, ticks, cpu }
    property var sessions: []
    readonly property int working: sessions.filter(s => s.state === "working").length
    readonly property int needsYou: sessions.filter(s => s.state === "attention").length

    signal attention(var s)
    signal finished(var s)
    signal resolved(var s)          // hết "cần bạn" (đã duyệt / đã làm tiếp)

    // trả về chính phiên vừa cập nhật / tạo mới
    function upsert(match, patch) {
        let result = null;
        const out = sessions.map(s => {
            if (!result && match(s)) { result = Object.assign({}, s, patch); return result; }
            return s;
        });
        if (!result) { result = Object.assign({ since: Date.now(), message: "", cpu: 0, ticks: 0, hooked: false }, patch); out.push(result); }
        sessions = out;
        return result;
    }

    // ---- sự kiện từ hook ----
    function event(ev) {
        const pids = ev.pids || [];
        if (ev.state === "end") {
            sessions = sessions.filter(s => !(s.agent === ev.agent && (s.key === ev.session || pids.indexOf(s.pid) >= 0)));
            return;
        }
        const prev = sessions.find(s => s.agent === ev.agent && (s.key === ev.session || (s.pid && pids.indexOf(s.pid) >= 0)));
        const wasWorking = prev?.state === "working";
        const s = upsert(x => prev !== undefined && x === prev, {
            key: ev.session || prev?.key || ("pid:" + (pids[0] ?? 0)),
            agent: ev.agent, cwd: ev.cwd || prev?.cwd || "", state: ev.state,
            message: ev.message || (ev.state === prev?.state ? prev?.message : "") || "",
            pid: prev?.pid ?? 0, pids: pids, hooked: true,
            since: ev.state !== prev?.state ? Date.now() : (prev?.since ?? Date.now()),
            workedFrom: ev.state === "working" ? (wasWorking ? prev.workedFrom : Date.now()) : (prev?.workedFrom ?? 0)
        });
        if (prev?.state === "attention" && ev.state !== "attention") resolved(s);
        if (ev.state === "attention") attention(s);
        // chỉ báo "xong" khi nó đã làm được một lúc (bỏ qua câu trả lời tức thì)
        else if (ev.state === "done" && (wasWorking || ev.agent === "codex") && Date.now() - (s.workedFrom || 0) > 4000) finished(s);
    }

    IpcHandler {
        target: "agents"
        function event(json: string): void { try { root.event(JSON.parse(json)); } catch (e) {} }
    }

    // ---- quét tiến trình ----
    property real lastPoll: 0
    Process {
        id: psProc
        command: ["islet-agent", "ps"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try { list = JSON.parse(text); } catch (e) { return; }
                const now = Date.now(), dt = Math.max(0.5, (now - root.lastPoll) / 1000);
                root.lastPoll = now;
                let out = [];
                for (const p of list) {
                    // phiên đã biết (từ hook hoặc lần quét trước) ứng với tiến trình này
                    const s = root.sessions.find(x => x.agent === p.agent && (x.pid === p.pid || (x.pids || []).indexOf(p.pid) >= 0));
                    const cpu = s && s.ticks ? Math.max(0, (p.ticks - s.ticks) / 100 / dt) : 0;
                    let state = s?.state ?? "idle";
                    // agent không có hook: đoán theo CPU. Giao diện terminal của agent lúc rảnh vẫn ăn ~10–15%,
                    // nên cần > 30% hai lần liền mới là "đang làm", < 15% hai lần liền mới về "rảnh".
                    let hi = s?.hi ?? 0, lo = s?.lo ?? 0;
                    if (!s?.hooked) {
                        hi = cpu > 0.30 ? hi + 1 : 0;
                        lo = cpu < 0.15 ? lo + 1 : 0;
                        if (hi >= 2) state = "working";
                        else if (lo >= 2 && state === "working") state = "idle";
                    }
                    out.push(Object.assign({ key: "pid:" + p.pid, message: "", since: now, hooked: false, workedFrom: 0 }, s || {}, {
                        agent: p.agent, pid: p.pid, pids: p.pids, cwd: s?.cwd || p.cwd, ticks: p.ticks, cpu: cpu,
                        hi: hi, lo: lo, state: state, since: s && s.state === state ? s.since : now
                    }));
                }
                // phiên từ hook mà tiến trình đã thoát → bỏ
                root.sessions = out;
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!psProc.running) psProc.running = true }

    // nối Claude Code / Codex với Islet (chỉ thêm phần của Islet, chạy lại vô hại)
    function setup() { if (!setupProc.running) setupProc.running = true; }
    Process { id: setupProc; command: ["islet-agent", "setup"] }
    // mỗi phút kiểm tra lại (vd. vừa cài Claude Code từ Cửa hàng)
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.setup() }

    // ---- nhảy tới cửa sổ terminal đang chạy agent ----
    function focus(s) {
        Hyprland.refreshToplevels();
        const pids = s?.pids || [];
        const t = Hyprland.toplevels.values.find(w => pids.indexOf(w.lastIpcObject?.pid) >= 0);
        if (!t) return false;
        if (Windows.isMinimized(t)) Windows.restore(t);
        else Windows.focusWin(t);
        return true;
    }
}
