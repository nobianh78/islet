import QtQuick

// Ba chấm 🔴 đóng · 🟡 thu nhỏ · 🟢 phóng to.
// lit = false: chấm xám (cửa sổ không được chọn); rê vào thì sáng màu + hiện ký hiệu.
Item {
    id: root

    property bool lit: true
    property bool maximized: false
    readonly property bool hovered: hover.hovered

    signal closeClicked()
    signal minimizeClicked()
    signal maximizeClicked()

    implicitWidth: row.implicitWidth
    implicitHeight: 12

    // Gắn vào item gốc để nhận hover cả khi con trỏ đang ở trên từng chấm.
    HoverHandler { id: hover }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
            model: [
                { color: "#FF5F57", ring: "#E0443E", glyph: "close" },
                { color: "#FEBC2E", ring: "#DEA123", glyph: "min" },
                { color: "#28C840", ring: "#1AAB29", glyph: root.maximized ? "restore" : "max" }
            ]

            Rectangle {
                id: dot
                required property var modelData
                required property int index
                readonly property bool on: root.lit || root.hovered
                width: 12
                height: 12
                radius: 6
                color: !on ? Qt.rgba(1, 1, 1, 0.22)
                    : m.pressed ? Qt.darker(modelData.color, 1.15) : modelData.color
                border.width: 0.5
                border.color: on ? modelData.ring : Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { ColorAnimation { duration: 160 } }
                scale: m.pressed ? 0.85 : m.containsMouse ? 1.12 : 1
                Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.005 } }

                Canvas {
                    anchors.fill: parent
                    opacity: root.hovered ? 0.85 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    property string kind: dot.modelData.glyph
                    onKindChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        const ink = Qt.darker(dot.modelData.color, 2.6);
                        c.strokeStyle = ink;
                        c.fillStyle = ink;
                        c.lineWidth = 1.3;
                        c.lineCap = "round";
                        const k = 6;
                        c.beginPath();
                        if (kind === "close") {
                            c.moveTo(k - 2.5, k - 2.5); c.lineTo(k + 2.5, k + 2.5);
                            c.moveTo(k + 2.5, k - 2.5); c.lineTo(k - 2.5, k + 2.5);
                            c.stroke();
                        } else if (kind === "min") {
                            c.moveTo(k - 3, k); c.lineTo(k + 3, k);
                            c.stroke();
                        } else if (kind === "max") {
                            c.moveTo(k - 3, k); c.lineTo(k + 3, k);
                            c.moveTo(k, k - 3); c.lineTo(k, k + 3);
                            c.stroke();
                        } else {
                            c.moveTo(k - 3, k - 0.6); c.lineTo(k - 0.6, k - 0.6); c.lineTo(k - 0.6, k - 3); c.closePath();
                            c.moveTo(k + 3, k + 0.6); c.lineTo(k + 0.6, k + 0.6); c.lineTo(k + 0.6, k + 3); c.closePath();
                            c.fill();
                        }
                    }
                }

                MouseArea {
                    id: m
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (dot.index === 0) root.closeClicked();
                        else if (dot.index === 1) root.minimizeClicked();
                        else root.maximizeClicked();
                    }
                }
            }
        }
    }
}
