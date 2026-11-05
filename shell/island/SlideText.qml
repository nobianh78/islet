import QtQuick
import "../theme"

// Chữ đổi thì trượt (chuyển từ lib/anim.js SlideLabel): dòng cũ bay lên mờ đi,
// dòng mới nhô lên từ dưới.
Item {
    id: root

    property string text: ""
    property color color: "#F2F2F7"
    property int pixelSize: 13
    property int weight: Font.DemiBold
    property int align: Text.AlignLeft

    implicitHeight: a.implicitHeight
    clip: true

    property bool useA: true
    property bool first: true

    onTextChanged: {
        const inc = useA ? b : a;
        const old = useA ? a : b;
        inc.text = text;
        if (first || !visible) {
            first = false;
            old.opacity = 0; inc.opacity = 1; inc.y = 0;
        } else {
            swap.incoming = inc;
            swap.outgoing = old;
            swap.restart();
        }
        useA = !useA;
    }
    Component.onCompleted: { a.text = text; first = false; }

    component Line: Text {
        width: root.width
        color: root.color
        font.family: Theme.font
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        elide: Text.ElideRight
        horizontalAlignment: root.align
    }
    Line { id: a }
    Line { id: b; opacity: 0 }

    ParallelAnimation {
        id: swap
        property Item incoming: b
        property Item outgoing: a
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: swap.incoming; property: "y"; from: root.height * 0.8; to: 0; duration: 560; easing.type: Easing.OutQuint }
                NumberAnimation { target: swap.incoming; property: "opacity"; from: 0; to: 1; duration: 560; easing.type: Easing.OutQuint }
            }
        }
        NumberAnimation { target: swap.outgoing; property: "y"; to: -root.height * 0.55; duration: 320; easing.type: Easing.InCubic }
        NumberAnimation { target: swap.outgoing; property: "opacity"; to: 0; duration: 320; easing.type: Easing.InCubic }
    }
}
