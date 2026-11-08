import QtQuick
import Quickshell
import "../theme"
import "../services"
import "../common"

// Cửa sổ "Widgets": kho widget của màn hình nền. Mỗi thẻ là một ô xem trước thật, bấm Add là
// thêm lên màn hình nền (thêm bao nhiêu cái cũng được — hai đồng hồ, hai khung ảnh…).
FloatingWindow {
    id: win

    title: "Widgets"
    implicitWidth: 900
    implicitHeight: 620
    minimumSize: Qt.size(700, 480)
    color: Theme.window
    visible: false

    Connections {
        target: Ui
        function onWidgetsOpenChanged() { if (Ui.widgetsOpen) { win.visible = true; intro.restart(); } else win.visible = false; }
        function onWidgetsRaiseRequested() { Windows.raiseShell("Widgets"); }
    }
    onVisibleChanged: if (!visible && Ui.widgetsOpen) Ui.widgetsOpen = false
    function close() { Ui.widgetsOpen = false; }
    function minimize() { if (!Windows.minimizeShell("Widgets")) win.minimized = true; }
    function toggleMaximize() { win.maximized = !win.maximized; }

    property string added: ""
    Timer { id: addedClear; interval: 2200; onTriggered: win.added = "" }
    function add(kind) {
        DesktopItems.addWidget(kind.id);
        win.added = kind.label;
        addedClear.restart();
        if (!Prefs.desktopWidgets) Prefs.set("desktopWidgets", true);
    }

    Item {
        id: panel
        anchors.fill: parent
        focus: true
        transformOrigin: Item.Top
        Keys.onEscapePressed: win.close()
        ParallelAnimation {
            id: intro
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; from: 0.98; to: 1; duration: 300; easing.type: Easing.OutCubic }
        }

        // ---------- thanh trên ----------
        Item {
            id: head
            width: parent.width; height: 76
            TitleDrag { anchors.fill: parent }
            WindowLights { x: 20; y: 19; onClose: win.close(); onMinimize: win.minimize(); onMaximize: win.toggleMaximize() }
            Row {
                x: 20; y: 38
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 9; color: Theme.tint(0.3)
                    TIcon { anchors.centerIn: parent; name: "grid"; size: 17 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Widgets"; color: Theme.label; font.family: Theme.font; font.pixelSize: 17; font.weight: Font.Bold }
                    Text {
                        text: win.added ? win.added + " added to the desktop"
                            : DesktopItems.widgets.length === 0 ? "Click a widget to put it on the desktop"
                            : DesktopItems.widgets.length + (DesktopItems.widgets.length === 1 ? " widget" : " widgets") + " on the desktop"
                        color: win.added ? "#34C77B" : Theme.muted; font.family: Theme.font; font.pixelSize: 11
                    }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 20
                y: 40
                spacing: 8
                Btn { label: "Tidy up"; onClicked: DesktopItems.resetPositions() }
                Btn { label: "New sticky note"; onClicked: { DesktopItems.focusNote(DesktopItems.addNote()); win.added = "Sticky note"; addedClear.restart(); } }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.fg(0.06) }
        }

        // ---------- kho ----------
        Flickable {
            anchors.top: head.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 20
            clip: true
            contentHeight: col.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                width: parent.width
                spacing: 18
                Repeater {
                    model: DesktopItems.widgetGroups
                    Column {
                        required property string modelData
                        width: col.width
                        spacing: 10
                        Text { text: parent.modelData; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
                        Flow {
                            width: parent.width
                            spacing: 14
                            Repeater {
                                model: DesktopItems.kinds.filter(k => k.group === parent.parent.modelData)
                                Rectangle {
                                    id: card
                                    required property var modelData
                                    width: 256; height: 212
                                    radius: 20
                                    color: cm.containsMouse ? Theme.fg(0.08) : Theme.fg(0.045)
                                    border.width: 1; border.color: Theme.fg(cm.containsMouse ? 0.14 : 0.07)
                                    Behavior on color { ColorAnimation { duration: 130 } }

                                    // ô xem trước: widget thật, thu nhỏ cho vừa thẻ
                                    Item {
                                        id: box
                                        x: 10; y: 10
                                        width: parent.width - 20; height: 126
                                        clip: true
                                        Rectangle { anchors.fill: parent; radius: 16; color: Theme.light ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(0.07, 0.07, 0.11, 0.92) }   // preview theo chủ đề như widget thật
                                        WidgetContent {
                                            readonly property real k: Math.min((box.width - 24) / card.modelData.w, (box.height - 20) / card.modelData.h, 1)
                                            width: card.modelData.w
                                            height: card.modelData.h
                                            x: (box.width - width * k) / 2
                                            y: (box.height - height * k) / 2
                                            scale: k
                                            transformOrigin: Item.TopLeft
                                            kind: card.modelData.id
                                            conf: card.modelData.conf ?? ({})
                                            preview: true
                                        }
                                    }
                                    Column {
                                        x: 16; y: 146
                                        width: parent.width - 100
                                        spacing: 2
                                        Text { text: card.modelData.label; color: Theme.label; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                        Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; text: card.modelData.d; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                                    }
                                    Btn {
                                        anchors.right: parent.right; anchors.rightMargin: 14
                                        y: 152
                                        label: "Add"; primary: true
                                        onClicked: win.add(card.modelData)
                                    }
                                    Rectangle {
                                        visible: DesktopItems.countOf(card.modelData.id) > 0
                                        x: 16; y: 16
                                        width: cnt.implicitWidth + 14; height: 20; radius: 10
                                        color: Theme.tint(0.5)
                                        Text { id: cnt; anchors.centerIn: parent; text: DesktopItems.countOf(card.modelData.id) + " on desktop"; color: Theme.label; font.family: Theme.font; font.pixelSize: 9; font.weight: Font.Bold }
                                    }
                                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; z: -1 }
                                }
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "Drag widgets anywhere on the desktop. Hover one and click the − in its corner to take it off again."
                    color: Theme.faint; font.family: Theme.font; font.pixelSize: 11
                }
            }
        }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool primary: false
        signal clicked()
        width: bl.implicitWidth + 28
        height: 30
        radius: 15
        color: primary ? (bm.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
                       : (bm.containsMouse ? Theme.fg(0.16) : Theme.fg(0.08))
        Behavior on color { ColorAnimation { duration: 130 } }
        scale: bm.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Text { id: bl; anchors.centerIn: parent; text: b.label; color: b.primary ? "#FFFFFF" : Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
}
