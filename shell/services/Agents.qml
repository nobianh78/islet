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
        opencode: { label: "OpenCode",    icon: "opencode" },
        // app có giao diện riêng (agent chạy bên trong app) — nhận tin qua thông báo hệ thống của app
        vscode:      { label: "VS Code",     icon: "visual-studio-code-bin", app: true, classes: ["code", "code-oss", "code-url-handler", "Code"] },
        cursor:      { label: "Cursor",      icon: "cursor-bin",             app: true, classes: ["cursor", "Cursor"] },
        antigravity: { label: "Antigravity", icon: "antigravity",            app: true, classes: ["antigravity", "Antigravity"] }
    })

    // ---- app editor (VS Code / Code-OSS / Cursor / Antigravity): đọc thông báo của chính app ----
    // Trả về true nếu thông báo là của agent trong editor (island hiện thông báo agent thay cho thông báo thường).
    function editorOf(n) {
        const id = ((n.desktopEntry || "") + " " + (n.appName || "")).toLowerCase();
        if (/antigravity/.test(id)) return "antigravity";
        if (/cursor/.test(id)) return "cursor";
        if (/\bcode\b|code - oss|code-oss|visual studio code|vscodium|com\.visualstudio/.test(id)) return "vscode";
        return "";
    }
    readonly property var askRe: /(confirm|approv|permission|allow|waiting for (your )?(input|approval|response)|needs? (your )?(input|attention|approval)|requires? (your )?(input|attention|approval)|run (this )?command\?)/i
    readonly property var doneRe: /(finish|complet|done|ready|response (is )?(received|ready)|responded|has replied|task (is )?(done|over))/i
    function fromNotification(n) {
        const ed = editorOf(n);
        if (!ed) return false;
        const text = (n.summary || "") + " " + (n.body || "").replace(/<[^>]*>/g, " ");
        const state = askRe.test(text) ? "attention" : doneRe.test(text) ? "done" : "";
        if (!state) return false;                          // thông báo thường của editor (cập nhật, lỗi…) → để nguyên
        const msg = (n.body || n.summary || "").replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
        const s = upsert(x => x.key === "app:" + ed, {
            key: "app:" + ed, agent: ed, app: true, state: state, message: msg, cwd: "",
            pid: 0, pids: [], hooked: true, since: Date.now(), workedFrom: 0
        });
        if (state === "attention") attention(s); else finished(s);
        return true;
    }
    function label(a) { return meta[a]?.label ?? a; }
    function iconOf(a) { return Qt.resolvedUrl("../assets/store/" + (meta[a]?.icon ?? "claude-code") + ".png"); }
    function project(cwd) { const p = (cwd || "").replace(/\/+$/, ""); return p === Quickshell.env("HOME") ? "Home" : p.substring(p.lastIndexOf("/") + 1) || p; }

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
        // chỉ báo "xong" khi nó đã làm > 1,5 giây (bỏ qua phản hồi tức thì)
        else if (ev.state === "done" && (wasWorking || ev.agent === "codex") && Date.now() - (s.workedFrom || 0) > 1500) finished(s);
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
                let out = [], done = [];
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
                    const startedWork = state === "working" && s?.state !== "working";
                    const o = Object.assign({ key: "pid:" + p.pid, message: "", since: now, hooked: false, workedFrom: 0 }, s || {}, {
                        agent: p.agent, pid: p.pid, pids: p.pids, cwd: s?.cwd || p.cwd, ticks: p.ticks, cpu: cpu,
                        hi: hi, lo: lo, state: state, since: s && s.state === state ? s.since : now,
                        workedFrom: startedWork ? now : (s?.workedFrom ?? 0)
                    });
                    out.push(o);
                    // không có hook: hết bận sau ≥ 6 giây làm việc → coi như xong
                    if (!o.hooked && s?.state === "working" && state === "idle" && now - (s.workedFrom || now) > 6000)
                        done.push(o);
                }
                // (phiên từ hook mà tiến trình đã thoát không có trong `out` → tự bị bỏ)
                // phiên của app editor: giữ lại khi cửa sổ app còn mở
                const wins = Hyprland.toplevels.values.map(w => w.lastIpcObject?.class ?? "");
                for (const a of root.sessions.filter(x => x.app))
                    if ((root.meta[a.agent]?.classes ?? []).some(c => wins.indexOf(c) >= 0)) out.push(a);
                root.sessions = out;
                for (const o of done) root.finished(o);
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!psProc.running) psProc.running = true }

    // OpenCode: nghe luồng sự kiện của server OpenCode (chạy mãi; tự chờ khi chưa có OpenCode)
    Process {
        id: ocWatch
        running: true
        command: ["islet-agent", "watch-opencode"]
        onExited: ocRestart.restart()
    }
    Timer { id: ocRestart; interval: 5000; onTriggered: ocWatch.running = true }

    // nối Claude Code / Codex với Islet (chỉ thêm phần của Islet, chạy lại vô hại)
    function setup() { if (!setupProc.running) setupProc.running = true; }
    Process { id: setupProc; command: ["islet-agent", "setup"] }
    // mỗi phút kiểm tra lại (vd. vừa cài Claude Code từ Cửa hàng)
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.setup() }

    // ---- nhảy tới cửa sổ terminal đang chạy agent ----
    function focus(s) {
        Hyprland.refreshToplevels();
        const pids = s?.pids || [];
        const classes = meta[s?.agent]?.classes ?? [];
        const t = Hyprland.toplevels.values.find(w => pids.indexOf(w.lastIpcObject?.pid) >= 0)
            ?? (s?.app ? Hyprland.toplevels.values.find(w => classes.indexOf(w.lastIpcObject?.class) >= 0) : null);
        if (!t) return false;
        if (Windows.isMinimized(t)) Windows.restore(t);
        else Windows.focusWin(t);
        return true;
    }
}
