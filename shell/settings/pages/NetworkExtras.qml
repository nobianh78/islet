import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../services"
import "../../common"
import "../../controlcenter"
import ".."
// Cài đặt › Wi-Fi & Network (phần thêm): chia sẻ Wi-Fi bằng mã QR, VPN WireGuard, IP tĩnh, proxy.
Column {
    id: page
    width: parent ? parent.width : 600
    spacing: 12
    property string ssid: ""             // mạng Wi-Fi đang nối (do Settings truyền vào)
    property string qr: ""
    property string msg: ""
    property var vpns: []                // { name, up }
    property var confs: []               // file .conf WireGuard tìm thấy trong ~/Downloads, ~
    property var ifaces: []
    property string iface: ""
    property bool proxyOn: false
    onVisibleChanged: if (visible) { loadVpn(); scanConfs.running = true; ifs.running = true; prx.running = true; }

    // ---- chia sẻ Wi-Fi bằng QR ----
    function share() {
        Admin.run(["wifi-psk", Qt.btoa(ssid)], (ok, out) => {
            if (!ok) { page.msg = out; return; }
            const esc = x => x.replace(/([\;,:"])/g, "\\$1");
            const payload = out === "OPEN" ? "WIFI:T:nopass;S:" + esc(ssid) + ";;" : "WIFI:T:WPA;S:" + esc(ssid) + ";P:" + esc(out) + ";;";
            // ảnh QR chứa mật khẩu → để trong thư mục riêng của phiên (chỉ bạn đọc được), không phải /tmp
            qrProc.command = ["qrencode", "-s", "8", "-m", "2", "-o", page.qrFile, payload];
            qrProc.running = true;
        });
    }
    readonly property string qrFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/islet-wifi-qr.png"
    Process { id: qrProc; onExited: code => { page.qr = code === 0 ? "file://" + page.qrFile + "?" + Date.now() : ""; if (code !== 0) page.msg = "Couldn't make the QR code"; } }

    // ---- VPN ----
    function loadVpn() { Admin.run(["wg", "list"], (ok, out) => { page.vpns = ok ? out.split("\n").filter(x => x).map(l => { const p = l.split(" "); return { name: p[0], up: p[1] === "up" }; }) : []; }); }
    Process {
        id: scanConfs
        command: ["sh", "-c", 'for f in "$HOME"/Downloads/*.conf "$HOME"/*.conf; do [ -f "$f" ] && grep -q "^\\[Interface\\]" "$f" && grep -q "^\\[Peer\\]" "$f" && echo "$f"; done; true']
        stdout: StdioCollector { onStreamFinished: page.confs = text.split("\n").filter(x => x) }
    }
    // ---- giao diện mạng ----
    Process {
        id: ifs
        command: ["sh", "-c", 'for d in /sys/class/net/*; do i=${d##*/}; case $i in lo|docker*|veth*|br-*|virbr*|wg*) continue;; esac; t=wired; [ -d "$d/wireless" ] && t=wifi; a=$(ip -4 -o addr show "$i" | awk "{print \\$4}" | head -1); echo "$i $t ${a:--}"; done']
        stdout: StdioCollector { onStreamFinished: { page.ifaces = text.split("\n").filter(x => x).map(l => { const p = l.split(" "); return { name: p[0], kind: p[1], addr: p[2] }; }); if (!page.iface && page.ifaces.length) page.iface = page.ifaces[0].name; } }
    }
    Process {
        id: prx
        command: ["sh", "-c", 'f="$HOME/.config/environment.d/islet-proxy.conf"; [ -f "$f" ] && sed -n "s/^http_proxy=//p" "$f" | head -1']
        stdout: StdioCollector { onStreamFinished: { page.proxyOn = text.trim() !== ""; if (text.trim()) proxyIn.text = text.trim().replace(/^https?:\/\//, ""); } }
    }

    // ===== giao diện =====
    SectionLabel { text: "Share Wi-Fi"; visible: page.ssid !== "" }
    Card {
        visible: page.ssid !== ""
        width: parent.width
        height: page.qr ? 250 : 64
        Behavior on height { SpringAnimation { spring: 4; damping: 0.4 } }
        Text { x: 18; y: 22; text: "Let a phone join “" + page.ssid + "”"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
        Pill { anchors.right: parent.right; anchors.rightMargin: 16; y: 16; label: page.qr ? "Hide" : "Show QR code"; primary: !page.qr; onClicked: page.qr ? page.qr = "" : page.share() }
        Rectangle {
            visible: page.qr !== ""
            x: 18; y: 62; width: 172; height: 172; radius: 14; color: Theme.label
            Image { anchors.centerIn: parent; width: 160; height: 160; source: page.qr; smooth: false; cache: false }
        }
        Text { visible: page.qr !== ""; x: 210; y: 80; width: parent.width - 230; wrapMode: Text.Wrap; text: "Open the camera on your phone and point it at the code to join without typing the password."; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
    }

    SectionLabel { text: "VPN (WireGuard)" }
    Card {
        width: parent.width
        height: vCol.implicitHeight + 8
        Column {
            id: vCol
            y: 4; width: parent.width
            Text { visible: page.vpns.length === 0; leftPadding: 18; topPadding: 14; bottomPadding: 14; width: vCol.width - 36; wrapMode: Text.Wrap; text: "No VPN yet. Download a WireGuard .conf file from your VPN provider, then import it below."; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
            Repeater {
                model: page.vpns
                Item {
                    id: vr
                    required property var modelData
                    required property int index
                    width: vCol.width; height: 56
                    HoverHandler { id: vh }
                    Rectangle { visible: vr.index > 0; x: 18; width: parent.width - 36; height: 1; color: Theme.fg(0.06) }
                    Column {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        Text { text: vr.modelData.name; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
                        Text { text: vr.modelData.up ? "Connected" : "Not connected"; color: vr.modelData.up ? "#34C77B" : Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Pill { visible: vh.hovered && !vr.modelData.up; label: "Remove"; onClicked: Admin.run(["wg", "remove", vr.modelData.name], () => page.loadVpn()) }
                        Toggle { anchors.verticalCenter: parent.verticalCenter; checked: vr.modelData.up; onToggled: Admin.run(["wg", vr.modelData.up ? "down" : "up", vr.modelData.name], (ok, out) => { page.msg = ok ? "" : out; page.loadVpn(); }) }
                    }
                }
            }
        }
    }
    Flow {
        width: parent.width; spacing: 8
        visible: page.confs.length > 0
        Text { text: "Import:"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; height: 30; verticalAlignment: Text.AlignVCenter }
        Repeater {
            model: page.confs
            Chip { required property string modelData; label: modelData.split("/").pop(); onClicked: Admin.run(["wg", "import", modelData], (ok, out) => { page.msg = ok ? "Imported VPN “" + out + "”" : out; page.loadVpn(); }) }
        }
    }

    SectionLabel { text: "IP address" }
    Card {
        width: parent.width
        height: ipCol.implicitHeight + 32
        Column {
            id: ipCol
            x: 18; y: 16; width: parent.width - 36; spacing: 10
            Flow {
                width: parent.width; spacing: 8
                Repeater { model: page.ifaces; Chip { required property var modelData; label: modelData.name + " · " + (modelData.kind === "wifi" ? "Wi-Fi" : "Wired") + " · " + modelData.addr; on: page.iface === modelData.name; onClicked: page.iface = modelData.name } }
            }
            Row {
                spacing: 8
                Field { id: ipIn; width: 170; hint: "192.168.1.50/24" }
                Field { id: gwIn; width: 140; hint: "Gateway 192.168.1.1" }
                Field { id: dnsIn; width: 120; hint: "DNS 1.1.1.1" }
            }
            Row {
                spacing: 8
                Pill { label: "Use this static IP"; primary: true; onClicked: Admin.run(["net", "static", page.iface, ipIn.text.trim(), gwIn.text.trim(), dnsIn.text.trim() || "1.1.1.1"], (ok, out) => { page.msg = ok ? "Static IP set on " + page.iface : out; ifs.running = true; }) }
                Pill { label: "Automatic (DHCP)"; onClicked: Admin.run(["net", "dhcp", page.iface], (ok, out) => { page.msg = ok ? "Back to automatic IP on " + page.iface : out; ifs.running = true; }) }
            }
        }
    }

    SectionLabel { text: "Proxy" }
    Card {
        width: parent.width; height: 104
        Text { x: 18; y: 16; text: "HTTP / HTTPS proxy for apps"; color: Theme.label; font.family: Theme.font; font.pixelSize: 13 }
        Row {
            x: 18; y: 52; spacing: 8
            Field { id: proxyIn; width: 260; hint: "host:port — e.g. 10.0.0.2:3128" }
            Pill {
                label: page.proxyOn ? "Update" : "Turn on"; primary: true
                onClicked: {
                    const v = proxyIn.text.trim(); if (!/^[A-Za-z0-9.-]+:\d{2,5}$/.test(v)) { page.msg = "Use host:port"; return; }
                    const host = v.split(":")[0], port = v.split(":")[1];
                    pxSet.command = ["sh", "-c", 'mkdir -p "$HOME/.config/environment.d"; printf "http_proxy=http://%s\\nhttps_proxy=http://%s\\nHTTP_PROXY=http://%s\\nHTTPS_PROXY=http://%s\\nno_proxy=localhost,127.0.0.1\\n" "$1" "$1" "$1" "$1" > "$HOME/.config/environment.d/islet-proxy.conf"; gsettings set org.gnome.system.proxy mode manual; gsettings set org.gnome.system.proxy.http host "$2"; gsettings set org.gnome.system.proxy.http port "$3"; gsettings set org.gnome.system.proxy.https host "$2"; gsettings set org.gnome.system.proxy.https port "$3"', "sh", v, host, port];
                    pxSet.running = true;
                }
            }
            Pill { visible: page.proxyOn; label: "Turn off"; onClicked: { pxSet.command = ["sh", "-c", 'rm -f "$HOME/.config/environment.d/islet-proxy.conf"; gsettings set org.gnome.system.proxy mode none']; pxSet.running = true; } }
        }
    }
    Process { id: pxSet; onExited: { page.msg = "Proxy saved — apps you open from now on use it"; prx.running = true; } }
    Text { visible: page.msg !== ""; width: parent.width; wrapMode: Text.Wrap; text: page.msg; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
}
