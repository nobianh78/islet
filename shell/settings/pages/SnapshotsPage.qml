import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Snapshots & Backup
//   · Btrfs + Snapper: bản lưu hệ thống tự động trước/sau mỗi lần cập nhật (snap-pac), tạo tay, quay lại
//   · Sao lưu thư mục Home ra ổ ngoài (rsync), có tiến trình
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property bool supported: false
    property bool checked: false
    property var snaps: []
    property string msg: ""
    onVisibleChanged: if (visible) { probe.running = true; targets.running = true; }
    Process {
        id: probe
        command: ["sh", "-c", "findmnt -no FSTYPE /"]
        stdout: StdioCollector { onStreamFinished: { page.supported = text.trim() === "btrfs"; page.checked = true; if (page.supported) page.list(); } }
    }
    function list() {
        Admin.run(["snapshot", "list"], (ok, out) => {
            if (!ok) { page.msg = out; return; }
            try {
                const d = JSON.parse(out); const l = d.root || d[Object.keys(d)[0]] || [];
                page.snaps = l.filter(x => x.number > 0).reverse();
            } catch (e) { page.msg = "Couldn't read snapshots"; }
        });
    }

    SectionLabel { text: "System snapshots" }
    Card {
        visible: page.checked && !page.supported
        width: parent.width; height: 96
        Icon { x: 18; y: 18; name: "warning"; size: 20; color: "#FFB547" }
        Column {
            x: 52; y: 16; width: parent.width - 70; spacing: 3
            Text { text: "Snapshots need a Btrfs system"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: "This computer was installed with ext4. Reinstall Islet and keep “Btrfs with snapshots” on in the installer to get automatic restore points before every update."; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
    }
    Column {
        visible: page.supported
        width: parent.width
        spacing: 12
        Row {
            spacing: 10
            Pill { label: "Create snapshot"; primary: true; onClicked: Admin.run(["snapshot", "create", Qt.btoa("Manual · " + Time.dateLong + " " + Time.time)], (ok, out) => { page.msg = ok ? "Snapshot created" : out; page.list(); }) }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "A snapshot is also taken before and after every update"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
        Card {
            width: parent.width
            height: sCol.implicitHeight + 8
            Column {
                id: sCol
                y: 4; width: parent.width
                Text { visible: page.snaps.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "No snapshots yet"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                Repeater {
                    model: page.snaps.slice(0, 15)
                    Item {
                        id: snRow
                        required property var modelData
                        required property int index
                        width: sCol.width; height: 52
                        property bool armed: false
                        HoverHandler { id: snh }
                        Rectangle { visible: snRow.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                        Column {
                            x: 18; anchors.verticalCenter: parent.verticalCenter
                            Text { text: snRow.modelData.description || ("Snapshot " + snRow.modelData.number); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                            Text { text: "#" + snRow.modelData.number + " · " + (snRow.modelData.date || "") + (snRow.modelData.type === "pre" ? " · before update" : snRow.modelData.type === "post" ? " · after update" : ""); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                        }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            visible: snh.hovered || snRow.armed
                            Pill {
                                label: snRow.armed ? "Click again to restore" : "Restore"
                                primary: snRow.armed
                                onClicked: {
                                    if (!snRow.armed) { snRow.armed = true; return; }
                                    Admin.run(["snapshot", "rollback", String(snRow.modelData.number)], (ok, out) => { page.msg = ok ? "Restart to finish restoring snapshot #" + snRow.modelData.number : out; snRow.armed = false; });
                                }
                            }
                            Pill { label: "Delete"; onClicked: Admin.run(["snapshot", "delete", String(snRow.modelData.number)], (ok, out) => { page.msg = ok ? "" : out; page.list(); }) }
                        }
                    }
                }
            }
        }
    }

    SectionLabel { text: "Back up your files" }
    property var drives: []
    property string target: ""
    property bool backing: false
    property string progress: ""
    Process {
        id: targets
        command: ["sh", "-c", "lsblk -J -o MOUNTPOINTS,RM,HOTPLUG,LABEL,FSAVAIL"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const walk = ds => { for (const d of ds || []) { walk(d.children); const m = (d.mountpoints || []).filter(x => x)[0]; if (m && (d.rm || d.hotplug) && m.startsWith("/run/media")) out.push({ mount: m, label: d.label || m.split("/").pop(), avail: d.fsavail }); } };
                try { walk(JSON.parse(text).blockdevices); } catch (e) {}
                page.drives = out;
                if (!out.some(x => x.mount === page.target)) page.target = out.length ? out[0].mount : "";
            }
        }
    }
    Process {
        id: rsync
        command: ["rsync", "-a", "--delete", "--info=progress2", "--no-inc-recursive",
                  "--exclude", ".cache", "--exclude", ".local/share/Trash", "--exclude", "node_modules", "--exclude", ".npm",
                  Quickshell.env("HOME") + "/", page.target + "/Islet Backup/" + (Quickshell.env("USER") || "home") + "/"]
        stdout: SplitParser { splitMarker: "\r"; onRead: l => { const m = l.match(/(\d+)%/); if (m) page.progress = m[1] + "%"; } }
        onExited: code => { page.backing = false; page.msg = code === 0 ? "Backup finished · " + Time.time : "Backup stopped (code " + code + ")"; }
    }
    Card {
        width: parent.width
        height: bCol.implicitHeight + 32
        Column {
            id: bCol
            x: 18; y: 16; width: parent.width - 36; spacing: 10
            Text { text: page.drives.length ? "Copy your Home folder to an external drive (caches and Trash are skipped)." : "Plug in a USB drive or external disk to back up your Home folder."; width: parent.width; wrapMode: Text.Wrap; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12 }
            Flow {
                width: parent.width; spacing: 8
                Repeater { model: page.drives; Chip { required property var modelData; label: modelData.label; on: page.target === modelData.mount; onClicked: page.target = modelData.mount } }
            }
            Row {
                spacing: 10
                visible: page.drives.length > 0
                Pill { label: page.backing ? "Backing up… " + page.progress : "Back up now"; primary: !page.backing; onClicked: if (!page.backing && page.target) { page.backing = true; page.progress = "0%"; rsync.running = true; } }
                Pill { visible: page.backing; label: "Stop"; onClicked: rsync.signal(15) }
                Pill { label: "Refresh drives"; onClicked: targets.running = true }
            }
        }
    }
    Text { visible: page.msg !== ""; width: parent.width; wrapMode: Text.Wrap; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
}
