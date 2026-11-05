import QtQuick
import Quickshell.Widgets
import "../theme"
import "../services"
import "../common"

// Banner (chuyển từ _fillBanner): thông báo · OSD âm lượng · toast (đang mở app, đang sạc, …)
Item {
    id: root

    property var banner: null          // { kind, title, body, appName, icon, level, text, tile }
    readonly property string kind: banner?.kind ?? ""

    // ================= thông báo =================
    Row {
        visible: root.kind === "notification"
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        ClippingRectangle {
            id: nIcon
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: 9
            color: Qt.rgba(1, 1, 1, 0.10)
            Image {
                id: nImg
                anchors.fill: parent
                source: root.kind === "notification" ? (root.banner?.icon ?? "") : ""
                sourceSize: Qt.size(76, 76)
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                visible: !nImg.visible
                name: "bell"
                size: 20
            }
            // icon nảy lên khi banner hiện
            scale: 1
            Connections {
                target: root
                function onBannerChanged() { if (root.kind === "notification") pop.restart(); }
            }
            NumberAnimation { id: pop; target: nIcon; property: "scale"; from: 0.4; to: 1; duration: 520; easing.type: Easing.OutBack }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - nIcon.width - 12
            spacing: 1
            Row {
                width: parent.width
                spacing: 8
                Text {
                    width: Math.min(implicitWidth, parent.width - app.width - 8)
                    text: root.banner?.title ?? ""
                    color: "#FFFFFF"
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    id: app
                    visible: (root.banner?.appName ?? "") !== "" && root.banner?.appName !== root.banner?.title
                    anchors.baseline: parent.children[0].baseline
                    text: root.banner?.appName ?? ""
                    color: "#8E8E93"
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: root.banner?.body ?? ""
                color: "#AEAEB2"
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }

    // ================= OSD (âm lượng) =================
    Row {
        visible: root.kind === "osd"
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        Icon {
            id: oIcon
            anchors.verticalCenter: parent.verticalCenter
            name: root.banner?.icon ?? "volume"
            size: 20
        }
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - oIcon.width - num.width - 24
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.18)
            Rectangle {
                height: parent.height
                radius: parent.radius
                color: "#FFFFFF"
                width: parent.width * Math.max(0, Math.min(1, root.banner?.level ?? 0))
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            id: num
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            horizontalAlignment: Text.AlignRight
            text: Math.round((root.banner?.level ?? 0) * 100)
            color: "#AEAEB2"
            font.family: Theme.font
            font.pixelSize: 13
            font.features: ({ "tnum": 1 })
        }
    }

    // ================= toast =================
    Row {
        visible: root.kind === "toast"
        anchors.centerIn: parent
        spacing: 10

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: (root.banner?.tile ?? "") !== ""
            size: 26
            name: root.banner?.iconUrl ? "" : (root.banner?.icon ?? "")
            source: root.banner?.iconUrl ?? ""
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: (root.banner?.tile ?? "") === ""
            name: visible ? (root.banner?.icon ?? "bolt") : ""
            size: 18
            color: root.banner?.iconColor ?? "#30D158"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.banner?.text ?? ""
            color: "#FFFFFF"
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }
    }
}
