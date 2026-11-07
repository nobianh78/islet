pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Đồ trên màn hình nền: widget (đồng hồ, lịch, thời tiết, máy) và ghi chú dán.
// Lưu ở ~/.config/islet/desktop.json:
//   { widgets: { clock: {on, x, y}, calendar: …, weather: …, system: … },
//     notes: [{ id, text, color, x, y, w, h }] }
// x, y tính từ góc trên trái màn hình chính; x < 0 = chưa đặt (tự xếp ở cột bên phải).
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/islet/desktop.json"
    readonly property var kinds: [
        { id: "clock",    label: "Clock",    w: 300, h: 150 },
        { id: "calendar", label: "Calendar", w: 300, h: 262 },
        { id: "weather",  label: "Weather",  w: 300, h: 176 },
        { id: "system",   label: "CPU & memory", w: 300, h: 132 }
    ]
    readonly property var noteColors: ["#FFD966", "#FF9EB5", "#8FD3FF", "#9BE7A8", "#C7B3FF", "#FFB877"]

    property var widgets: ({ clock: { on: true, x: -1, y: -1 }, calendar: { on: true, x: -1, y: -1 },
                             weather: { on: true, x: -1, y: -1 }, system: { on: false, x: -1, y: -1 } })
    property var notes: []
    // chỉ đổi khi thêm / bỏ ghi chú (Repeater dựng lại ghi chú ⇒ mất con trỏ đang gõ, nên không dùng thẳng `notes`)
    property ListModel noteModel: ListModel {}
    function note(id) { return notes.find(n => n.id === id) ?? null; }
    function order(id) { return notes.findIndex(n => n.id === id); }
    function syncModel() {
        const ids = notes.map(n => n.id);
        for (let i = noteModel.count - 1; i >= 0; i--) if (ids.indexOf(noteModel.get(i).nid) < 0) noteModel.remove(i);
        const have = [];
        for (let i = 0; i < noteModel.count; i++) have.push(noteModel.get(i).nid);
        for (const id of ids) if (have.indexOf(id) < 0) noteModel.append({ nid: id });
    }
    property bool loaded: false
    property int editing: 0                   // số ghi chú đang gõ (cần bàn phím cho lớp màn hình nền)

    function widget(id) { return widgets[id] ?? { on: false, x: -1, y: -1 }; }
    function setWidget(id, patch) {
        const w = Object.assign({}, widgets);
        w[id] = Object.assign({}, widget(id), patch);
        widgets = w;
        save.restart();
    }
    function toggle(id) { setWidget(id, { on: !widget(id).on }); }

    // ---- ghi chú ----
    function addNote(x, y) {
        const id = Date.now().toString(36) + Math.floor(Math.random() * 1000);
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

    FileView {
        id: file
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text() || "{}");
                if (d.widgets && typeof d.widgets === "object") root.widgets = Object.assign({}, root.widgets, d.widgets);
                if (Array.isArray(d.notes)) root.notes = d.notes.filter(n => n && n.id);
                root.syncModel();
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
    Timer {
        id: save
        interval: 400
        onTriggered: file.setText(JSON.stringify({ widgets: root.widgets, notes: root.notes }, null, 1))
    }
}
