import QtQuick
import "../theme"

// Một câu lời, chạy chữ giống Dynamic Island cho GNOME (lib/anim.js › LyricLine):
//   · câu mới: từng từ nhô lên từ dưới, nối đuôi nhau (cách 34 ms), mờ → hiện
//   · karaoke: từ chưa hát mờ (41%), sáng lên đúng lúc được hát (theo tỉ lệ số chữ trong câu)
//   · câu cũ: bay lên, mờ đi, thu nhỏ một chút
//   · câu dài hơn chỗ trống: trượt ngang chậm theo thời lượng của câu (marquee)
Item {
    id: root
    property string text: ""
    property string key: text              // điệp khúc lặp lại vẫn là câu mới (key khác)
    property real elapsed: 0               // giây đã hát của câu này
    property real duration: 3              // thời lượng câu (giây)
    property bool karaoke: true            // false: hiện sáng hết (tên bài…)
    property int pixelSize: 13
    property int weight: Font.Bold
    property color color: "#FFFFFF"
    property real dimLevel: 105 / 255
    property bool center: false

    implicitHeight: probe.implicitHeight + 2
    clip: true
    Text { id: probe; visible: false; text: "Ág"; font.family: Theme.font; font.pixelSize: root.pixelSize; font.weight: root.weight }

    property Item cur: null
    onKeyChanged: swap()
    Component.onCompleted: swap()
    function swap() {
        const old = cur;
        const animate = old !== null && root.visible && root.width > 1;
        cur = lineComp.createObject(root, { text: root.text, animateIn: animate });
        if (old) old.leave(animate);
    }
    // cùng câu nhưng chữ đổi (ví dụ tên bài khi không có lời)
    onTextChanged: if (cur && !cur.leaving && cur.text !== text && key === text) swap()

    Component {
        id: lineComp
        Item {
            id: box
            property string text: ""
            property bool animateIn: false
            property bool leaving: false
            readonly property var words: text.split(/\s+/).filter(w => w.length > 0)
            // điểm bắt đầu của mỗi từ trong câu, theo số chữ (như bản GNOME)
            readonly property var fracs: {
                const total = words.reduce((n, w) => n + w.length, 0) || 1;
                let acc = 0;
                return words.map(w => { const f = acc / total; acc += w.length; return f; });
            }
            property real mx: 0
            width: row.implicitWidth
            height: root.height
            x: (root.center && row.implicitWidth < root.width ? (root.width - row.implicitWidth) / 2 : 0) + mx
            transformOrigin: Item.Left

            Row {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(root.pixelSize * 0.3)
                Repeater {
                    model: box.words.length
                    Text {
                        id: w
                        required property int index
                        text: box.words[index]
                        readonly property bool lit: !root.karaoke || box.leaving || root.elapsed >= box.fracs[index] * root.duration * 0.92
                        property real intro: box.animateIn ? 0 : 1
                        property real litV: lit ? 1 : root.dimLevel
                        Behavior on litV { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                        opacity: intro * litV
                        transform: Translate { y: (1 - w.intro) * root.height * 0.8 }
                        color: root.color
                        font.family: Theme.font
                        font.pixelSize: root.pixelSize
                        font.weight: root.weight
                        SequentialAnimation {
                            running: box.animateIn
                            PauseAnimation { duration: 60 + Math.min(w.index, 14) * 34 }
                            NumberAnimation { target: w; property: "intro"; to: 1; duration: 560; easing.type: Easing.OutQuint }
                        }
                    }
                }
            }

            function leave(animate) {
                leaving = true;
                if (!animate) { destroy(); return; }
                out.start();
            }
            ParallelAnimation {
                id: out
                NumberAnimation { target: box; property: "opacity"; to: 0; duration: 320; easing.type: Easing.InCubic }
                NumberAnimation { target: box; property: "y"; to: -root.height * 0.55; duration: 320; easing.type: Easing.InCubic }
                NumberAnimation { target: box; property: "scale"; to: 0.96; duration: 320; easing.type: Easing.InCubic }
                onFinished: box.destroy()
            }
            // câu dài: đợi island nở xong rồi trượt ngang hết câu trong khoảng thời lượng của nó
            Timer {
                interval: 900
                running: !box.leaving
                onTriggered: {
                    const over = row.implicitWidth - root.width;
                    if (over <= 4) return;
                    marquee.to = -over - 6;
                    marquee.duration = root.karaoke ? Math.max(1500, root.duration * 750) : 6000;
                    marquee.start();
                }
            }
            NumberAnimation { id: marquee; target: box; property: "mx"; easing.type: Easing.InOutSine }
        }
    }
}
