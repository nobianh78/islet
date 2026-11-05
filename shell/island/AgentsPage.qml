import QtQuick
import "../theme"

// Tab Agents — đợt 2 sẽ nối Claude Code / Codex: trạng thái phiên, Cho phép / Từ chối ngay trên island.
Item {
    implicitHeight: msg.implicitHeight
    Text {
        id: msg
        width: parent.width
        topPadding: 24
        bottomPadding: 24
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        lineHeight: 1.3
        text: "No agents yet.\nClaude Code integration is coming soon."
        color: "#8E8E93"
        font.family: Theme.font
        font.pixelSize: 12
    }
}
