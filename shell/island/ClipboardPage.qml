import QtQuick
import "../theme"

// Tab Clipboard — đợt 2 sẽ có lịch sử (chữ, ảnh, file), ghim, bấm để copy lại.
Item {
    implicitHeight: col.implicitHeight
    Column {
        id: col
        width: parent.width
        spacing: 8
        Text {
            text: "0 items"
            color: "#8E8E93"
            font.family: Theme.font
            font.pixelSize: 12
        }
        Text {
            width: parent.width
            topPadding: 18
            bottomPadding: 22
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Copy something — your history shows up here"
            color: "#8E8E93"
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
