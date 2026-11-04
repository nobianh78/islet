import QtQuick
import "../theme"

// Cột sóng nhạc. Nhảy khi đang phát, hạ xuống thấp khi tạm dừng.
Item {
    id: root

    property bool playing: false
    property int bars: 4
    property real barWidth: 4
    property real spacing: 3
    property color top: Theme.pink
    property color bottom: Theme.violet

    implicitWidth: bars * barWidth + (bars - 1) * spacing
    implicitHeight: 22

    Row {
        anchors.bottom: parent.bottom
        spacing: root.spacing

        Repeater {
            model: root.bars

            Rectangle {
                id: bar
                required property int index
                property real level: 0.25
                readonly property int period: [460, 620, 380, 540, 700][index % 5]

                width: root.barWidth
                height: Math.max(root.barWidth, root.height * level)
                anchors.bottom: parent.bottom
                radius: root.barWidth / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: root.top }
                    GradientStop { position: 1; color: root.bottom }
                }

                Behavior on level {
                    enabled: !root.playing
                    SpringAnimation { spring: 3; damping: 0.4 }
                }

                SequentialAnimation on level {
                    running: root.playing && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: bar.period; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.35; duration: bar.period * 0.8; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.8; duration: bar.period * 0.6; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.25; duration: bar.period; easing.type: Easing.InOutSine }
                }

                Connections {
                    target: root
                    function onPlayingChanged() { if (!root.playing) bar.level = 0.25; }
                }
            }
        }
    }
}
