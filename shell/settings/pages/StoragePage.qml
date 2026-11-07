import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Storage: dung lượng các ổ, thư mục nào chiếm nhiều, dọn dẹp (thùng rác, cache, gói cũ, nhật ký).
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property var drives: []        // { mount, size, used }
    property var folders: []       // { name, path, bytes }
    property var sizes: ({})       // khoá dọn dẹp → bytes
    property string msg: ""
    onVisibleChanged: if (visible) refresh()
    function refresh() { df.running = true; du.running = true; clean.running = true; }
    function human(b) { b = +b || 0; return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? Math.round(b / 1e6) + " MB" : Math.round(b / 1e3) + " KB"; }

    Process {
        id: df
        command: ["sh", "-c", "df -B1 --output=target,size,used -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs | tail -n +2"]
        stdout: StdioCollector { onStreamFinished: page.drives = text.trim().split("\n").map(l => l.trim().split(/\s+/)).filter(p => p.length === 3 && p[0] !== "/boot" && !p[0].startsWith("/run/archiso")).map(p => ({ mount: p[0], size: +p[1], used: +p[2] })) }
    }
    Process {
        id: du
        command: ["sh", "-c", 'cd "$HOME" && for d in Documents Downloads Pictures Videos Music Projects Desktop .cache .local/share/Trash; do [ -d "$d" ] && printf "%s\\t%s\\n" "$d" "$(du -sb "$d" 2>/dev/null | cut -f1)"; done']
        stdout: StdioCollector { onStreamFinished: page.folders = text.trim().split("\n").map(l => l.split("\t")).filter(p => p.length === 2).map(p => ({ name: p[0] === ".cache" ? "App caches" : p[0] === ".local/share/Trash" ? "Trash" : p[0], path: p[0], bytes: +p[1] })).sort((a, b) => b.bytes - a.bytes) }
    }
    // dung lượng các mục dọn được
    Process {
        id: clean
        command: ["sh", "-c", 's() { du -sb "$@" 2>/dev/null | awk "{t+=\\$1} END {print t+0}"; }; ' +
            'echo "trash $(s "$HOME/.local/share/Trash")"; ' +
            'echo "thumbs $(s "$HOME/.cache/thumbnails")"; ' +
            'echo "devcache $(s "$HOME/.cache/pip" "$HOME/.npm/_cacache" "$HOME/.cache/yarn" "$HOME/.cache/go-build" "$HOME/.cache/pnpm")"; ' +
            'echo "pkgcache $(s /var/cache/pacman/pkg)"; echo "journal $(s /var/log/journal)"; ' +
            'echo "orphans $(pacman -Qtdq 2>/dev/null | wc -l)"']
        stdout: StdioCollector { onStreamFinished: { const o = {}; for (const l of text.trim().split("\n")) { const p = l.split(" "); o[p[0]] = +p[1]; } page.sizes = o; } }
    }
    Process { id: userClean; onExited: { page.msg = "Cleaned up"; page.refresh(); } }

    // ---- ổ đĩa ----
    Repeater {
        model: page.drives
        Card {
            required property var modelData
            width: page.width; height: 78
            readonly property real frac: modelData.size ? modelData.used / modelData.size : 0
            Icon { x: 18; y: 16; name: "disk"; size: 20 }
            Text { x: 50; y: 14; text: modelData.mount === "/" ? "Islet (System)" : modelData.mount.split("/").pop(); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 16; text: page.human(modelData.size - modelData.used) + " free of " + page.human(modelData.size); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            Rectangle {
                x: 18; y: 48; width: parent.width - 36; height: 10; radius: 5; color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle { width: Math.max(10, parent.width * parent.parent.frac); height: parent.height; radius: 5; color: parent.parent.frac > 0.9 ? "#FF5F57" : Theme.accent }
            }
        }
    }

    SectionLabel { text: "Largest folders" }
    Card {
        width: parent.width
        height: fCol.implicitHeight + 8
        Column {
            id: fCol
            y: 4; width: parent.width
            Text { visible: page.folders.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "Measuring…"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.folders
                Item {
                    required property var modelData
                    required property int index
                    width: fCol.width; height: 42
                    readonly property real frac: page.folders.length ? modelData.bytes / Math.max(1, page.folders[0].bytes) : 0
                    Rectangle { visible: parent.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                    Text { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 150; elide: Text.ElideRight; text: parent.modelData.name; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                    Rectangle { x: 176; anchors.verticalCenter: parent.verticalCenter; width: (parent.width - 290) * parent.frac + 4; height: 6; radius: 3; color: Theme.tint(0.7) }
                    Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: page.human(parent.modelData.bytes); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["nautilus", Quickshell.env("HOME") + "/" + parent.modelData.path]) }
                }
            }
        }
    }

    SectionLabel { text: "Clean up" }
    Card {
        width: parent.width
        height: cCol.implicitHeight + 8
        Column {
            id: cCol
            y: 4; width: parent.width
            Repeater {
                model: [
                    { k: "trash",    t: "Trash",                     s: "Files you deleted", admin: "" },
                    { k: "thumbs",   t: "Thumbnails",                s: "Picture previews — rebuilt when needed", admin: "" },
                    { k: "devcache", t: "Developer caches",          s: "pip, npm, yarn, pnpm and Go build caches", admin: "" },
                    { k: "pkgcache", t: "Old package downloads",     s: "Keeps the newest copy of each package", admin: "pkgcache" },
                    { k: "orphans",  t: "Unused packages",           s: "Libraries nothing needs any more", admin: "orphans" },
                    { k: "journal",  t: "System logs",               s: "Keeps the most recent 100 MB", admin: "journal" }
                ]
                Item {
                    id: crow
                    required property var modelData
                    required property int index
                    width: cCol.width; height: 56
                    readonly property real amount: page.sizes[modelData.k] ?? -1
                    Rectangle { visible: crow.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                    Column {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        Text { text: crow.modelData.t; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: crow.modelData.s; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    Text {
                        anchors.right: cbtn.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        text: crow.amount < 0 ? "…" : crow.modelData.k === "orphans" ? crow.amount + " packages" : page.human(crow.amount)
                        color: "#AEAEB2"; font.family: Theme.font; font.pixelSize: 12
                    }
                    Pill {
                        id: cbtn
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        label: "Clean"
                        onClicked: {
                            const k = crow.modelData.k;
                            if (crow.modelData.admin) { Admin.run(["clean", crow.modelData.admin], (ok, out) => { page.msg = ok ? "Cleaned up" : out; page.refresh(); }); return; }
                            const sh = k === "trash" ? 'gio trash --empty'
                                : k === "thumbs" ? 'rm -rf -- "$HOME/.cache/thumbnails"'
                                : 'rm -rf -- "$HOME/.cache/pip" "$HOME/.npm/_cacache" "$HOME/.cache/yarn" "$HOME/.cache/go-build" "$HOME/.cache/pnpm"';
                            userClean.command = ["sh", "-c", sh];
                            userClean.running = true;
                        }
                    }
                }
            }
        }
    }
    Text { visible: page.msg !== ""; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
}
