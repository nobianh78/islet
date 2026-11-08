// Thành phần dùng chung của app Cài đặt.
import QtQuick
import "../theme"
import "../common"

Text {
    width: parent ? parent.width : 300
    wrapMode: Text.Wrap
    color: Theme.faint
    font.family: Theme.font
    font.pixelSize: 11
}
