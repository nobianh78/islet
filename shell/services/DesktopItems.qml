pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Đồ trên màn hình nền: widget, ghi chú dán và chỗ đứng của các icon file.
// Lưu ở ~/.config/islet/desktop.json:
//   { widgets: [{ uid, kind, x, y, conf }], notes: [{ id, text, color, x, y, w, h }],
//     files: { "<tên>": {x, y} }, stacks: bool }
// Thêm được nhiều widget cùng loại (hai đồng hồ hai múi giờ…). x < 0 = chưa đặt → tự xếp.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/islet/desktop.json"

    // ---- kho widget ----
    //   group: nhóm trong cửa sổ Widgets · w/h: cỡ mặc định · conf: cài riêng của từng cái
    readonly property var kinds: [
        { id: "clock",    label: "Clock",        group: "Time",     w: 300, h: 150, d: "Time and date" },
        { id: "analog",   label: "Analog clock", group: "Time",     w: 190, h: 190, d: "A quiet round clock" },
        { id: "world",    label: "World clock",  group: "Time",     w: 300, h: 176, d: "Times in other cities", conf: { zones: ["Asia/Ho_Chi_Minh", "Asia/Tokyo", "Europe/London", "America/New_York"] } },
        { id: "calendar", label: "Calendar",     group: "Time",     w: 300, h: 262, d: "This month, with your notes marked" },
        { id: "timer",    label: "Timer",        group: "Time",     w: 300, h: 150, d: "Countdown and Pomodoro from the island" },
        { id: "weather",  label: "Weather",      group: "Life",     w: 300, h: 176, d: "Now and the next few days" },
        { id: "media",    label: "Now playing",  group: "Life",     w: 300, h: 150, d: "What's playing, with controls" },
        { id: "photo",    label: "Photo frame",  group: "Life",     w: 260, h: 200, d: "Pictures from a folder, one by one", conf: { dir: "", secs: 20 } },
        { id: "launch",   label: "Quick launch", group: "Life",     w: 300, h: 112, d: "Your pinned apps, one click away" },
        { id: "system",   label: "CPU & memory", group: "Computer", w: 300, h: 132, d: "How busy the processor and memory are" },
        { id: "disk",     label: "Disk space",   group: "Computer", w: 300, h: 132, d: "What's left on your drives" },
        { id: "net",      label: "Network",      group: "Computer", w: 300, h: 132, d: "Up and down speed right now" },
        { id: "battery",  label: "Battery",      group: "Computer", w: 230, h: 132, d: "Charge left and time remaining" },
        { id: "sysinfo",  label: "This computer", group: "Computer", w: 300, h: 150, d: "Islet version, uptime, hostname" }
    ]
    readonly property var groups: ["Time", "Life", "Computer"]
    function kind(id) { return kinds.find(k => k.id === id) ?? null; }

    readonly property var noteColors: ["#FFD966", "#FF9EB5", "#8FD3FF", "#9BE7A8", "#C7B3FF", "#FFB877"]

    property var widgets: []
    property var notes: []
    property var files: ({})          // tên file → { x, y }
    property bool stacks: false       // gom icon theo loại (Stacks)
    property bool loaded: false

    // Repeater dựng lại delegate khi danh sách đổi (mất con trỏ đang gõ / đang kéo),
    // nên model chỉ chứa id và chỉ đổi khi thêm / bỏ.
    property ListModel noteModel: ListModel {}
    property ListModel widgetModel: ListModel {}
    function note(id) { return notes.find(n => n.id === id) ?? null; }
    function order(id) { return notes.findIndex(n => n.id === id); }
    function widget(uid) { return widgets.find(w => w.uid === uid) ?? null; }

    function syncOne(model, ids, key) {
        for (let i = model.count - 1; i >= 0; i--) if (ids.indexOf(model.get(i)[key]) < 0) model.remove(i);
        const have = [];
        for (let i = 0; i < model.count; i++) have.push(model.get(i)[key]);
        for (const id of ids) if (have.indexOf(id) < 0) model.append({ [key]: id });
    }
    function syncModel() {
        syncOne(noteModel, notes.map(n => n.id), "nid");
        syncOne(widgetModel, widgets.map(w => w.uid), "wid");
    }
    function newId() { return Date.now().toString(36) + Math.floor(Math.random() * 1000); }

    // ---- widget ----
    signal added(string uid)
    function addWidget(kindId, x, y) {
        const k = kind(kindId);
        if (!k) return "";
        const uid = newId();
        widgets = widgets.concat([{ uid: uid, kind: kindId, x: Math.round(x ?? -1), y: Math.round(y ?? -1),
                                    conf: JSON.parse(JSON.stringify(k.conf ?? {})) }]);
        syncModel();
        save.restart();
        added(uid);
        return uid;
    }
    function setWidget(uid, patch) {
        widgets = widgets.map(w => w.uid === uid ? Object.assign({}, w, patch) : w);
        save.restart();
    }
    function setConf(uid, patch) {
        const w = widget(uid);
        if (w) setWidget(uid, { conf: Object.assign({}, w.conf ?? {}, patch) });
    }
    function removeWidget(uid) { widgets = widgets.filter(w => w.uid !== uid); syncModel(); save.restart(); }
    function countOf(kindId) { return widgets.filter(w => w.kind === kindId).length; }
    function resetPositions() { widgets = widgets.map(w => Object.assign({}, w, { x: -1, y: -1 })); save.restart(); }

    // ---- ghi chú ----
    function addNote(x, y) {
        const id = newId();
        const c = noteColors[notes.length % noteColors.length];
        notes = notes.concat([{ id: id, text: "", color: c, x: Math.round(x ?? 120 + notes.length * 28), y: Math.round(y ?? 110 + notes.length * 28), w: 230, h: 210 }]);
        syncModel();
        save.restart();
        return id;
    }
    function setNote(id, patch) {
        notes = notes.map(n => n.id === id ? Object.assign({}, n, patch) : n);
        save.restart();
    }
    function removeNote(id) { notes = notes.filter(n => n.id !== id); syncModel(); save.restart(); }
    function raiseNote(id) {
        const n = notes.find(x => x.id === id);
        if (!n || notes[notes.length - 1].id === id) return;
        notes = notes.filter(x => x.id !== id).concat([n]);
        save.restart();
    }
    signal focusNote(string id)

    // ---- chỗ đứng của icon file ----
    function filePos(name) { return files[name] ?? null; }
    function setFilePos(name, x, y) {
        const f = Object.assign({}, files);
        f[name] = { x: Math.round(x), y: Math.round(y) };
        files = f;
        save.restart();
    }
    function clearFilePos(name) { const f = Object.assign({}, files); delete f[name]; files = f; save.restart(); }
    function tidyFiles() { files = ({}); save.restart(); }
    function setStacks(on) { stacks = on; save.restart(); }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text() || "{}");
                if (Array.isArray(d.widgets)) {
                    root.widgets = d.widgets.filter(w => w && w.uid && root.kind(w.kind));
                } else if (d.widgets && typeof d.widgets === "object") {
                    // bản cũ: { clock: {on, x, y}, … } → danh sách
                    const out = [];
                    for (const k of root.kinds) {
                        const o = d.widgets[k.id];
                        if (o && o.on) out.push({ uid: root.newId() + k.id, kind: k.id, x: o.x ?? -1, y: o.y ?? -1, conf: JSON.parse(JSON.stringify(k.conf ?? {})) });
                    }
                    root.widgets = out;
                }
                if (Array.isArray(d.notes)) root.notes = d.notes.filter(n => n && n.id);
                if (d.files && typeof d.files === "object") root.files = d.files;
                if (typeof d.stacks === "boolean") root.stacks = d.stacks;
            } catch (e) {}
            root.syncModel();
            root.loaded = true;
        }
        onLoadFailed: {
            // máy mới: đồng hồ, lịch, thời tiết sẵn ở cột bên phải
            root.widgets = ["clock", "calendar", "weather"].map(k => ({ uid: root.newId() + k, kind: k, x: -1, y: -1, conf: {} }));
            root.syncModel();
            root.loaded = true;
        }
    }
    Timer {
        id: save
        interval: 400
        onTriggered: file.setText(JSON.stringify({ widgets: root.widgets, notes: root.notes, files: root.files, stacks: root.stacks }, null, 1))
    }
}
