import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Storage › điểm khôi phục & sao lưu
//   · Btrfs + Snapper: điểm khôi phục tự động trước mỗi lần cập nhật (snap-pac), tạo tay, quay lại,
//     khởi động vào điểm cũ từ menu khởi động (islet-snapshot-boot)
//   · Sao lưu thư mục Home ra ổ ngoài (rsync), có tiến trình
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property string msg: ""
    onVisibleChanged: if (visible) { Restore.refresh(); targets.running = true; }
    readonly property bool supported: Restore.supported
    readonly property var snaps: Restore.snaps

    // ---------- đang chạy từ một điểm khôi phục (chọn ở menu khởi động) ----------
    Card {
        visible: Restore.booted > 0
        width: parent.width
        height: bootCol.implicitHeight + 36
        border.width: 1; border.color: Qt.rgba(1, 0.71, 0.28, 0.5)
        Column {
            id: bootCol
            x: 20; y: 18; width: parent.width - 40; spacing: 10
            Row {
                spacing: 10
                Icon { name: "history"; size: 20; color: "#FFB547"; anchors.verticalCenter: parent.verticalCenter }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "You're running a restore point"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.Bold }
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: (Restore.bootedSnap ? "“" + Restore.label(Restore.bootedSnap) + "” · " + Restore.bootedSnap.when + ". " : "")
                    + "Changes to the system made now are temporary — your files in Home are safe either way. If everything works, keep this version; otherwise just restart to return to the current system."
                color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12
            }
            Row {
                spacing: 8
                Pill {
                    label: Restore.needsRestart ? "Restart now" : "Keep this version"; primary: true
                    onClicked: Restore.needsRestart ? Restore.reboot() : Restore.restore(Restore.booted)
                }
                Pill { visible: !Restore.needsRestart; label: "Restart to current system"; onClicked: Restore.reboot() }
            }
        }
    }

    SectionLabel { text: "Restore points" }
    Card {
        visible: Restore.checked && !page.supported
        width: parent.width; height: 96
        Icon { x: 18; y: 18; name: "warning"; size: 20; color: "#FFB547" }
        Column {
            x: 52; y: 16; width: parent.width - 70; spacing: 3
            Text { text: "Restore points need a Btrfs system"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { width: parent.width; wrapMode: Text.Wrap; text: "This computer was installed with ext4. Reinstall Islet and keep “Btrfs with snapshots” on in the installer to get a restore point before every update."; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
    }
    Column {
        visible: page.supported
        width: parent.width
        spacing: 12

        // ---------- hoàn tác bản cập nhật gần nhất ----------
        Card {
            id: undo
            visible: Restore.booted === 0 && Restore.lastUpdate !== null
            width: parent.width
            height: 96
            property bool armed: false
            Rectangle {
                x: 18; anchors.verticalCenter: parent.verticalCenter; width: 48; height: 48; radius: 14; color: Theme.tint(0.25)
                Icon { anchors.centerIn: parent; name: "history"; size: 22 }
            }
            Column {
                x: 80; anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80 - undoBtn.width - 36
                spacing: 3
                Text { text: "Something broke after an update?"; color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text {
                    width: parent.width; wrapMode: Text.Wrap
                    text: Restore.needsRestart ? "Restart to finish going back. Your files in Home stay as they are."
                        : "Go back to how the system was " + (Restore.lastUpdate?.when ?? "").replace(/^Today/, "today at").replace(/^Yesterday/, "yesterday at") + ", before the update. Your files in Home stay as they are."
                    color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                }
            }
            Pill {
                id: undoBtn
                anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                label: Restore.needsRestart ? "Restart now" : undo.armed ? "Click again to go back" : "Go back"
                primary: undo.armed || Restore.needsRestart
                onClicked: {
                    if (Restore.needsRestart) { Restore.reboot(); return; }
                    if (!undo.armed) { undo.armed = true; disarm.restart(); return; }
                    undo.armed = false;
                    Restore.restore(Restore.lastUpdate.number);
                }
                Timer { id: disarm; interval: 5000; onTriggered: undo.armed = false }
            }
        }

        Row {
            spacing: 10
            Pill { label: "Create restore point"; onClicked: Restore.create("Manual · " + Time.dateLong + " " + Time.time) }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "One is made automatically before every update"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
        }
        Card {
            width: parent.width
            height: sCol.implicitHeight + 8
            Column {
                id: sCol
                y: 4; width: parent.width
                Text { visible: page.snaps.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; text: "No restore points yet"; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
                Repeater {
                    model: page.snaps.filter(s => s.type !== "post").slice(0, 15)
                    Item {
                        id: snRow
                        required property var modelData
                        required property int index
                        width: sCol.width; height: 52
                        property bool armed: false
                        HoverHandler { id: snh }
                        Rectangle { visible: snRow.index > 0; x: 18; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                        Icon {
                            x: 18; anchors.verticalCenter: parent.verticalCenter; size: 16; opacity: 0.75
                            name: snRow.modelData.type === "pre" ? "download" : "history"
                        }
                        Column {
                            x: 46; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46 - acts.width - 30
                            Text { width: parent.width; elide: Text.ElideRight; text: Restore.label(snRow.modelData); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13 }
                            Text { text: snRow.modelData.when + (Restore.booted === snRow.modelData.number ? " · running now" : ""); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 11 }
                        }
                        Row {
                            id: acts
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            visible: snh.hovered || snRow.armed
                            Pill {
                                label: snRow.armed ? "Click again to go back" : "Go back to this"
                                primary: snRow.armed
                                onClicked: {
                                    if (!snRow.armed) { snRow.armed = true; return; }
                                    snRow.armed = false;
                                    Restore.restore(snRow.modelData.number);
                                }
                            }
                            Pill { label: "Delete"; onClicked: Restore.remove(snRow.modelData.number) }
                        }
                    }
                }
            }
        }
        Hint { text: "Can't get to the desktop? Restart and hold Space while the computer starts — pick an earlier restore point from the menu, then choose “Keep this version” here." }
        Text { visible: Restore.msg !== ""; width: parent.width; wrapMode: Text.Wrap; text: Restore.msg; color: Restore.needsRestart ? "#34C77B" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
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
