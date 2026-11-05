import QtQuick
import "../theme"

// Đồng hồ kiểu công-tơ-mét (chuyển từ lib/clock.js): chữ số đổi thì trượt lên biến mất,
// số mới bật lên từ dưới; số sau trễ hơn một chút như máy đếm. Dấu ":" thở mỗi giây.
Row {
    id: root

    property string text: "00:00"
    property int pixelSize: 17
    property int weight: Font.Bold
    property color color: "#FFFFFF"
    property color colonColor: "#FFD60A"
    property bool breathe: true

    spacing: 0

    Repeater {
        model: root.text.length

        Item {
            id: slot
            required property int index
            readonly property string ch: root.text.charAt(index)
            readonly property bool isColon: ch === ":"
            property string shown: ch
            property string leaving: ""

            width: Math.max(cur.implicitWidth, out.implicitWidth) + (isColon ? 2 : 0)
            height: cur.implicitHeight
            clip: true

            onChChanged: {
                if (ch === shown) return;
                leaving = shown;
                shown = ch;
                roll.restart();
            }

            Text {
                id: out
                anchors.horizontalCenter: parent.horizontalCenter
                text: slot.leaving
                color: root.color
                font.family: Theme.font
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.features: ({ "tnum": 1 })
                opacity: 0
            }
            Text {
                id: cur
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenterOffset: slot.isColon ? -1 : 0
                text: slot.shown
                color: slot.isColon ? root.colonColor : root.color
                font.family: Theme.font
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                font.features: ({ "tnum": 1 })

                SequentialAnimation on opacity {
                    running: slot.isColon && root.breathe
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.24; duration: 480; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 480; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 40 }
                }
            }

            SequentialAnimation {
                id: roll
                PauseAnimation { duration: slot.index * 35 }
                ParallelAnimation {
                    NumberAnimation { target: cur; property: "y"; from: slot.height; to: 0; duration: 520; easing.type: Easing.OutBack }
                    NumberAnimation { target: cur; property: "opacity"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
                    NumberAnimation { target: out; property: "y"; from: 0; to: -slot.height; duration: 360; easing.type: Easing.InQuad }
                    NumberAnimation { target: out; property: "opacity"; from: 1; to: 0; duration: 360; easing.type: Easing.InQuad }
                }
            }
        }
    }
}
