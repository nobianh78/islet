// Một dòng cài đặt: tiêu đề + mô tả + công tắc (dùng trong Card).
import QtQuick
import "../theme"

Item {
    id: r
    property string title: ""
    property string sub: ""
    property bool checked: false
    property bool divider: false
    signal toggled()
    width: parent ? parent.width : 400
    height: 58
    Rectangle { visible: r.divider; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
    Column {
        x: 18; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 100
        Text { width: parent.width; elide: Text.ElideRight; text: r.title; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
        Text { visible: r.sub !== ""; width: parent.width; elide: Text.ElideRight; text: r.sub; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
    }
    Toggle { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: r.checked; onToggled: r.toggled() }
}
