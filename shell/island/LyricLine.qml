import QtQuick
import "../theme"

// Một câu lời kiểu karaoke: chữ mờ, phần đã hát sáng dần từ trái sang (progress 0…1).
// Đổi câu (key khác) thì câu cũ bay lên mờ đi, câu mới nhô lên từ dưới — như SlideText.
// Câu dài hơn chỗ trống thì trượt ngang theo phần đang hát.
Item {
    id: root
    property string text: ""
    property string key: text             // điệp khúc lặp lại vẫn đổi câu (key khác nhau)
    property real progress: 0
    property int pixelSize: 13
    property int weight: Font.Bold
    property color color: "#FFFFFF"
    property color dim: Qt.rgba(1, 1, 1, 0.38)
    property bool karaoke: true

    implicitHeight: probe.implicitHeight
    clip: true
    Text { id: probe; visible: false; text: "Ág"; font.family: Theme.font; font.pixelSize: root.pixelSize; font.weight: root.weight }

    property bool useA: true
    onKeyChanged: {
        const inc = useA ? b : a, old = useA ? a : b;
        inc.text = text; inc.live = true; old.live = false;
        if (!visible || old.text === "") { old.opacity = 0; inc.opacity = 1; inc.y = 0; }
        else { swap.incoming = inc; swap.outgoing = old; swap.restart(); }
        useA = !useA;
    }
    // dòng đang hiện là a khi useA, b khi không
    onTextChanged: { const cur = useA ? a : b; if (cur.live) cur.text = text; }
    Component.onCompleted: { a.text = text; a.live = true; }

    component Line: Item {
        id: ln
        property string text: ""
        property bool live: false
        readonly property real fill: live ? (root.karaoke ? root.progress : 1) : 1
        width: root.width
        height: root.height
        // trượt ngang khi câu dài: giữ phần đang hát ở khoảng 65% bề ngang
        readonly property real over: Math.max(0, base.implicitWidth - width)
        property real shift: over <= 0 ? 0 : Math.min(over, Math.max(0, base.implicitWidth * fill - width * 0.65))
        Text {
            id: base
            x: -ln.shift
            anchors.verticalCenter: parent.verticalCenter
            text: ln.text
            color: root.karaoke ? root.dim : root.color
            font.family: Theme.font; font.pixelSize: root.pixelSize; font.weight: root.weight
        }
        Item {
            id: ov
            x: -ln.shift
            height: parent.height
            width: base.implicitWidth * ln.fill
            clip: true
            visible: root.karaoke
            // (không dùng Behavior: tiến độ đổi mỗi khung hình, animation sẽ bị khởi động lại mãi và đứng ở 0)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ln.text
                color: root.color
                font.family: Theme.font; font.pixelSize: root.pixelSize; font.weight: root.weight
            }
        }
    }
    Line { id: a }
    Line { id: b; opacity: 0 }

    ParallelAnimation {
        id: swap
        property Item incoming
        property Item outgoing
        NumberAnimation { target: swap.outgoing; property: "y"; to: -root.height * 0.6; duration: 320; easing.type: Easing.InCubic }
        NumberAnimation { target: swap.outgoing; property: "opacity"; to: 0; duration: 280 }
        NumberAnimation { target: swap.incoming; property: "y"; from: root.height * 0.7; to: 0; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: swap.incoming; property: "opacity"; from: 0; to: 1; duration: 300 }
    }
}
