import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Default Apps: app mặc định cho trình duyệt, email, video, nhạc, ảnh, PDF, văn bản, thư mục.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    readonly property var kinds: [
        { k: "web",   label: "Web browser", icon: "globe",    probe: "x-scheme-handler/https", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"] },
        { k: "mail",  label: "Email",       icon: "bell",     probe: "x-scheme-handler/mailto", mimes: ["x-scheme-handler/mailto"] },
        { k: "video", label: "Videos",      icon: "play",     probe: "video/mp4", mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"] },
        { k: "music", label: "Music",       icon: "music",    probe: "audio/mpeg", mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"] },
        { k: "image", label: "Photos",      icon: "image",    probe: "image/png", mimes: ["image/png", "image/jpeg", "image/webp", "image/gif", "image/svg+xml"] },
        { k: "pdf",   label: "PDF",         icon: "document", probe: "application/pdf", mimes: ["application/pdf"] },
        { k: "text",  label: "Text files",  icon: "code",     probe: "text/plain", mimes: ["text/plain", "text/markdown", "application/json", "text/x-python", "application/x-shellscript"] },
        { k: "dir",   label: "Folders",     icon: "folder",   probe: "inode/directory", mimes: ["inode/directory"] }
    ]
    property var current: ({})       // k → id
    property var options: ({})       // k → [[id, name]]
    property string open: ""
    onVisibleChanged: if (visible) load.running = true
    Process {
        id: load
        command: ["sh", "-c", page.kinds.map(x => 'printf "%s\\tC\\t%s\\n" ' + x.k + ' "$(islet-defaults get ' + x.probe + ')"; islet-defaults list ' + x.probe + ' | sed "s/^/' + x.k + '\\tO\\t/"').join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = {}, opt = {};
                for (const l of text.split("\n")) {
                    const p = l.split("\t");
                    if (p.length < 3) continue;
                    if (p[1] === "C") cur[p[0]] = p[2];
                    else (opt[p[0]] = opt[p[0]] || []).push([p[2], p[3] || p[2]]);
                }
                page.current = cur; page.options = opt;
            }
        }
    }
    function nameOf(k, id) { const o = (options[k] || []).find(x => x[0] === id); return o ? o[1] : (id ? id.replace(/\.desktop$/, "") : "Not set"); }

    Card {
        width: parent.width
        height: dCol.implicitHeight + 8
        Column {
            id: dCol
            y: 4; width: parent.width
            Repeater {
                model: page.kinds
                Column {
                    id: kind
                    required property var modelData
                    required property int index
                    width: dCol.width
                    Item {
                        width: parent.width; height: 54
                        Rectangle { visible: kind.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                        Rectangle { x: 16; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 9; color: Theme.fg(0.08); TIcon { anchors.centerIn: parent; name: kind.modelData.icon; size: 15 } }
                        Text { x: 58; anchors.verticalCenter: parent.verticalCenter; text: kind.modelData.label; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(260, cur.implicitWidth + 36); height: 30; radius: 10
                            color: km.containsMouse || page.open === kind.modelData.k ? Theme.fg(0.14) : Theme.fg(0.07)
                            Text { id: cur; x: 12; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: page.nameOf(kind.modelData.k, page.current[kind.modelData.k]); color: Theme.label; font.family: Theme.font; font.pixelSize: 12 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: page.open === kind.modelData.k ? "▴" : "▾"; color: Theme.muted; font.pixelSize: 11 }
                            MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.open = page.open === kind.modelData.k ? "" : kind.modelData.k }
                        }
                    }
                    // danh sách app chọn được
                    Flow {
                        visible: page.open === kind.modelData.k
                        x: 58; width: parent.width - 76
                        spacing: 6
                        bottomPadding: 12
                        Text { visible: (page.options[kind.modelData.k] || []).length === 0; text: "No installed app can open this — get one in the Store"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                        Repeater {
                            model: page.options[kind.modelData.k] || []
                            Chip {
                                required property var modelData
                                label: modelData[1]
                                on: page.current[kind.modelData.k] === modelData[0]
                                onClicked: {
                                    Quickshell.execDetached(["islet-defaults", "set", modelData[0]].concat(kind.modelData.mimes));
                                    const c = Object.assign({}, page.current); c[kind.modelData.k] = modelData[0]; page.current = c;
                                    page.open = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Hint { text: "Files you double-click open in these apps. You can still pick another app from “Open With” in Files." }
}
