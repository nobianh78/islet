import QtQuick
import "../theme"
import "../services"

// Tab Hiệu năng: 4 thẻ có biểu đồ 60 giây + hàng thông tin nhanh.
Item {
    id: root

    readonly property real gap: 14
    readonly property real cardW: (width - gap) / 2
    readonly property real cardH: (height - 46 - gap * 2) / 2

    component Card: Rectangle {
        id: card
        property string title: ""
        property string value: ""
        property string sub: ""
        property color tint: Theme.violet
        default property alias extra: slot.data
        width: root.cardW
        height: root.cardH
        radius: 20
        color: Theme.fg(0.05)
        border.width: 1
        border.color: Theme.fg(0.06)

        Row {
            x: 16
            y: 14
            spacing: 8
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: card.tint }
            Text { text: card.title; color: Theme.subtle; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        }
        Text {
            x: 16
            y: 34
            text: card.value
            color: Theme.label
            font.family: Theme.font
            font.pixelSize: 26
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
        }
        Text {
            x: 16
            y: 68
            text: card.sub
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }
        Item {
            id: slot
            x: 12
            y: 88
            width: parent.width - 24
            height: parent.height - 100
        }
    }

    Grid {
        columns: 2
        spacing: root.gap

        Card {
            title: "CPU"
            tint: Theme.violet
            value: Math.round(SysMon.cpu) + "%"
            sub: SysMon.cores.length + " cores" + (SysMon.temp !== null ? " · " + Math.round(SysMon.temp) + "°C" : "")
            Sparkline { anchors.fill: parent; values: SysMon.cpuHist; max: 100; color: Theme.violet }
        }
        Card {
            title: "Memory"
            tint: "#4BE3E8"
            value: SysMon.bytes(SysMon.mem.used)
            sub: "of " + SysMon.bytes(SysMon.mem.total) + " · " + Math.round(SysMon.mem.used / SysMon.mem.total * 100) + "%"
                + (SysMon.mem.swapTotal > 0 ? " · swap " + SysMon.bytes(SysMon.mem.swapUsed) : "")
            Sparkline { anchors.fill: parent; values: SysMon.memHist; max: 100; color: "#4BE3E8" }
        }
        Card {
            title: "Network"
            tint: "#4ADE80"
            value: "↓ " + SysMon.rate(SysMon.net.rx)
            sub: "↑ " + SysMon.rate(SysMon.net.tx) + " up"
            Sparkline { anchors.fill: parent; values: SysMon.rxHist; values2: SysMon.txHist; max: 0; color: "#4ADE80"; color2: "#FFB547" }
        }
        Card {
            title: "Disk"
            tint: "#FF6B97"
            value: SysMon.bytes(SysMon.disk.used)
            sub: "of " + SysMon.bytes(SysMon.disk.total) + " · read " + SysMon.rate(SysMon.disk.read) + " · write " + SysMon.rate(SysMon.disk.write)
            // thanh dung lượng + biểu đồ đọc/ghi
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.fg(0.1)
                Rectangle {
                    height: parent.height
                    radius: 3
                    width: parent.width * Math.min(1, SysMon.disk.used / SysMon.disk.total)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#FF6B97" }
                        GradientStop { position: 1; color: "#FFB547" }
                    }
                }
            }
            Sparkline { y: 12; width: parent.width; height: parent.height - 12; values: SysMon.diskHist; max: 0; color: "#FF6B97" }
        }
    }

    // các nhân CPU (thanh nhỏ ở góc phải thẻ CPU)
    Row {
        id: cpuBars
        x: root.cardW - width - 16
        y: 20
        spacing: 3
        Repeater {
            model: SysMon.cores
            Rectangle {
                required property var modelData
                width: 5
                height: 30
                radius: 2.5
                color: Theme.fg(0.08)
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: 2.5
                    height: Math.max(3, parent.height * parent.modelData / 100)
                    color: parent.modelData > 80 ? "#FF6B97" : Theme.violet
                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // hàng thông tin nhanh
    Row {
        anchors.bottom: parent.bottom
        spacing: 10
        Repeater {
            model: [
                ["Temperature", SysMon.temp !== null ? Math.round(SysMon.temp) + "°C" : "—"],
                ["Processes", String(SysMon.procs.length)],
                ["Uptime", SysMon.duration(SysMon.uptime)],
                ["Open apps", String(Windows.openCount)]
            ]
            Rectangle {
                required property var modelData
                height: 34
                width: chip.implicitWidth + 26
                radius: 17
                color: Theme.fg(0.05)
                Row {
                    id: chip
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: modelData[0]; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    Text { text: modelData[1]; color: Theme.label; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
            }
        }
    }
}
