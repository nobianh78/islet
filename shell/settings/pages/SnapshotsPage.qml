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
    onVisibleChanged: if (visible) { Restore.refresh(); Backup.refresh(); Backup.refreshList(); }
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

    // ================= Time Machine =================
    SectionLabel { text: "Time Machine" }
    Card {
        width: parent.width
        height: tmCol.implicitHeight + 36
        Column {
            id: tmCol
            x: 20; y: 18; width: parent.width - 40; spacing: 14
            Row {
                width: parent.width; spacing: 14
                Rectangle {
                    width: 48; height: 48; radius: 14
                    color: Backup.running ? Theme.tint(0.3) : Backup.connected ? Qt.rgba(0.2, 0.78, 0.48, 0.2) : Qt.rgba(1, 1, 1, 0.07)
                    Icon { anchors.centerIn: parent; name: "backup"; size: 22; color: Backup.connected && !Backup.running ? "#34C77B" : "#FFFFFF" }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 62 - tmBtns.width - 14
                    spacing: 3
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: !Prefs.backupDrive ? "Back up your files automatically"
                            : Backup.running ? "Backing up to " + Prefs.backupLabel + "… " + Backup.pct + "%"
                            : Prefs.backupLabel + (Backup.connected ? " · connected" : " · not connected")
                        color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width; wrapMode: Text.Wrap
                        text: !Prefs.backupDrive ? "Pick an external drive below. Every time you plug it in, Islet copies your Home folder and keeps a version for each day, so you can get back any file as it was."
                            : Backup.error ? Backup.error
                            : "Last backup: " + Backup.when(Prefs.backupLast)
                              + (Backup.connected ? (Prefs.backupAuto ? " · next in about an hour" : "") : " · plug the drive in to back up")
                              + (Backup.list.length > 1 ? " · " + Backup.list.length + " versions kept" : "")
                        color: Backup.error ? "#FF8A8A" : "#8E8E93"; font.family: Theme.font; font.pixelSize: 12
                    }
                }
                Row {
                    id: tmBtns
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Pill { visible: Backup.connected && !Backup.running; label: "Back up now"; primary: true; onClicked: Backup.backup() }
                    Pill { visible: Backup.running; label: "Stop"; onClicked: Backup.stop() }
                    Pill { visible: Backup.connected && Backup.list.length > 0; label: "Browse"; onClicked: Ui.openBackups() }
                }
            }
            Rectangle {
                visible: Backup.running
                width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle { height: parent.height; radius: 3; width: Math.max(6, parent.width * Backup.pct / 100); color: Theme.accent; Behavior on width { NumberAnimation { duration: 300 } } }
            }

            // chọn ổ
            Text {
                text: Backup.drives.length ? (Prefs.backupDrive ? "Backup drive" : "Choose a drive") : "Plug in a USB drive or external disk to use it for backups."
                color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12
            }
            Flow {
                width: parent.width; spacing: 8
                visible: Backup.drives.length > 0
                Repeater {
                    model: Backup.drives
                    Chip {
                        required property var modelData
                        label: Backup.label(modelData) + (modelData.size ? " · " + Math.round(modelData.size / 1e9) + " GB" : "")
                        on: Prefs.backupDrive === modelData.uuid
                        onClicked: Backup.choose(modelData)
                    }
                }
                Chip { visible: Prefs.backupDrive !== "" && !Backup.connected; label: Prefs.backupLabel + " (not connected)"; on: true }
            }
            Text {
                visible: Backup.drive !== null && !Backup.drive.history
                width: parent.width; wrapMode: Text.Wrap
                text: "This drive uses " + (Backup.drive?.fstype ?? "") + ", which can only hold the latest copy. Format it as ext4, Btrfs or NTFS (in Disks) to keep a version for every day."
                color: "#FFB547"; font.family: Theme.font; font.pixelSize: 12
            }
            Row {
                spacing: 18
                visible: Prefs.backupDrive !== ""
                Row {
                    spacing: 10
                    Toggle { anchors.verticalCenter: parent.verticalCenter; checked: Prefs.backupAuto; onToggled: Prefs.set("backupAuto", !Prefs.backupAuto) }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Back up automatically when plugged in"; color: "#D1D1D6"; font.family: Theme.font; font.pixelSize: 12 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "<a href=\"x\">Stop using this drive</a>"; textFormat: Text.StyledText; linkColor: "#8E8E93"
                    font.family: Theme.font; font.pixelSize: 12
                    onLinkActivated: Backup.forget()
                }
            }
        }
    }
    Hint { text: "Backups skip caches, Trash and build folders. Old versions are thinned out over time (every backup from today, one per day for a month, then one per week) and the oldest go first when the drive is full." }
    Text { visible: page.msg !== ""; width: parent.width; wrapMode: Text.Wrap; text: page.msg; color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12 }
}
