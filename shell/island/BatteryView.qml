import QtQuick
import "../theme"
import "../services"

// Hiện thoáng qua khi cắm sạc.
View {
    id: root
    width: 320
    height: 40

    // Số phần trăm chạy từ 0 lên mức thật cho vui mắt.
    property real shownPct: 0
    onShownChanged: {
        if (shown) { shownPct = 0; countUp.restart(); }
    }
    NumberAnimation {
        id: countUp
        target: root
        property: "shownPct"
        to: Power.percent
        duration: 700
        easing.type: Easing.OutCubic
    }

    Row {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Image {
            id: bolt
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            sourceSize: Qt.size(32, 32)
            source: Qt.resolvedUrl("../assets/icons/bolt.svg")
            SequentialAnimation on scale {
                running: root.shown
                loops: Animation.Infinite
                NumberAnimation { to: 1.2; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Đang sạc"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.shownPct) + "%"
            color: Theme.green
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }

        // Biểu tượng pin vẽ tay.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 14
            Rectangle {
                width: 25
                height: 14
                radius: 4
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.5)
                border.width: 1.4
                Rectangle {
                    x: 2.5
                    y: 2.5
                    height: parent.height - 5
                    radius: 2
                    width: (parent.width - 5) * Math.min(1, root.shownPct / 100)
                    color: Theme.green
                }
            }
            Rectangle {
                x: 26
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 5
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.5)
            }
        }
    }
}
