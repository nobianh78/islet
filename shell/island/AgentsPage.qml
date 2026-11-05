import QtQuick
import "../theme"
import "../services"
import "../common"

// Tab Agents: các agent lập trình đang chạy (Claude Code, Codex, Gemini CLI, OpenCode).
// Mỗi thẻ: agent · dự án · trạng thái (đang làm / cần bạn / chờ bạn / xong) · việc gần nhất.
// Bấm thẻ → nhảy tới cửa sổ terminal của agent đó.
Item {
    id: root
    signal picked()

    readonly property var rows: Agents.sessions.slice().sort((a, b) => rank(a.state) - rank(b.state) || b.since - a.since)
    function rank(st) { return { attention: 0, working: 1, waiting: 2, done: 3, idle: 4 }[st] ?? 5; }

    implicitHeight: list.length ? Math.min(col.implicitHeight, 270) : empty.implicitHeight

    property real now: Date.now()
    Timer { interval: 1000; running: root.visible && root.rows.length > 0; repeat: true; onTriggered: root.now = Date.now() }
    function elapsed(t) {
        const s = Math.max(0, Math.floor((now - t) / 1000));
        if (s < 60) return s + "s";
        if (s < 3600) return Math.floor(s / 60) + "m " + (s % 60) + "s";
        return Math.floor(s / 3600) + "h " + Math.floor(s % 3600 / 60) + "m";
    }
    readonly property var stateInfo: ({
        working:   { text: "Working",          color: Theme.accent },
        attention: { text: "Needs your OK",    color: "#FFB547" },
        waiting:   { text: "Waiting for you",  color: "#5EEAD4" },
        done:      { text: "Done",             color: "#34C77B" },
        idle:      { text: "Idle",             color: "#8E8E93" }
    })

    Column {
        id: empty
        visible: root.rows.length === 0
        width: parent.width
        topPadding: 16
        bottomPadding: 18
        spacing: 6
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No agents running"
            color: "#D1D1D6"
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Start claude, codex, gemini or opencode in a terminal —\nthe island tells you when it needs you or is done."
            color: "#8E8E93"
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.25
        }
    }

    Flickable {
        visible: root.rows.length > 0
        width: parent.width
        height: Math.min(col.implicitHeight, 270)
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 8
            Repeater {
                model: root.rows
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property var st: root.stateInfo[modelData.state] ?? root.stateInfo.idle
                    readonly property bool hot: modelData.state === "attention"
                    width: col.width
                    height: 62
                    radius: 18
                    color: cmA.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: hot ? 1.5 : 0
                    border.color: Qt.rgba(1, 0.71, 0.28, hotPulse)
                    property real hotPulse: 0.8
                    SequentialAnimation on hotPulse {
                        loops: Animation.Infinite
                        running: card.hot
                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.9; duration: 700; easing.type: Easing.InOutSine }
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: cmA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (Agents.focus(card.modelData)) root.picked(); }
                    }

                    // icon agent + vòng quay khi đang làm
                    Item {
                        id: ic
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 38
                        Rounded {
                            anchors.centerIn: parent
                            width: 32; height: 32
                            radius: 9
                            Image { anchors.fill: parent; source: Agents.iconOf(card.modelData.agent); sourceSize: Qt.size(64, 64); smooth: true }
                        }
                        Canvas {
                            id: ring
                            anchors.fill: parent
                            visible: card.modelData.state === "working"
                            property real a: 0
                            NumberAnimation on a { from: 0; to: Math.PI * 2; duration: 1100; loops: Animation.Infinite; running: ring.visible }
                            onAChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d"); c.reset();
                                c.lineWidth = 2.5; c.lineCap = "round"; c.strokeStyle = Theme.accent;
                                c.beginPath(); c.arc(19, 19, 17.5, a, a + Math.PI * 0.9); c.stroke();
                            }
                        }
                    }

                    Column {
                        anchors.left: ic.right
                        anchors.leftMargin: 10
                        anchors.right: chip.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Row {
                            spacing: 6
                            Text { text: Agents.label(card.modelData.agent); color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { text: Agents.project(card.modelData.cwd); color: "#8E8E93"; font.family: Theme.font; font.pixelSize: 12; anchors.baseline: parent.children[0].baseline }
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.message || (card.modelData.state === "working" ? "Thinking…" : card.modelData.cwd)
                            elide: Text.ElideRight
                            color: "#AEAEB2"
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }

                    // trạng thái + thời gian
                    Column {
                        id: chip
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Rectangle {
                            anchors.right: parent.right
                            height: 22
                            width: chipText.implicitWidth + 18
                            radius: 11
                            color: Qt.rgba(card.st.color.r, card.st.color.g, card.st.color.b, 0.18)
                            Text { id: chipText; anchors.centerIn: parent; text: card.st.text; color: card.st.color; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Bold }
                        }
                        Text {
                            anchors.right: parent.right
                            text: root.elapsed(card.modelData.since)
                            color: "#636366"
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
