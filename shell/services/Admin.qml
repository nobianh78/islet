pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Chạy `sudo islet-admin …` cho app Cài đặt.
//   Admin.run(["timezone", "Asia/Ho_Chi_Minh"], (ok, out) => …)
// sudo còn nhớ mật khẩu → chạy luôn; không thì hỏi mật khẩu (askPassword), kiểm tra MỘT lần qua PAM
// (Auth.qml) rồi mới đưa cho sudo — gõ sai không bị tính 3 lần như sudo -S.
Singleton {
    id: root

    property bool askPassword: false
    property string reason: ""
    property string error: ""
    property var queue: []           // { args, cb, input }
    property var current: null
    readonly property bool busy: current !== null || queue.length > 0

    function run(args, cb, input) {
        queue = queue.concat([{ args: args, cb: cb || (() => {}), input: input || "" }]);
        pump();
    }
    function pump() {
        if (current || askPassword || queue.length === 0) return;
        current = queue[0];
        queue = queue.slice(1);
        nopw.command = ["sudo", "-n", "islet-admin"].concat(current.args);
        nopw.running = true;
    }
    function submit(pw) {
        error = "";
        Auth.verify(pw, ok => {
            if (!ok) { error = "Wrong password"; return; }
            askPassword = false;
            withpw.pw = pw;
            withpw.command = ["sudo", "-S", "-p", "", "islet-admin"].concat(current.args);
            withpw.running = true;
        });
    }
    function cancel() {
        askPassword = false;
        const c = current; current = null; queue = [];
        c?.cb(false, "Cancelled");
    }
    function finish(code, out, err) {
        const c = current; current = null;
        c?.cb(code === 0, (out || "").trim() || (err || "").replace(/^ERROR /, "").trim());
        pump();
    }

    // thử không cần mật khẩu trước (sudo còn nhớ / live session không mật khẩu)
    Process {
        id: nopw
        stdinEnabled: true
        onStarted: { if (root.current?.input) write(root.current.input + "\n"); stdinEnabled = false; }
        stdout: StdioCollector { id: nopwOut }
        stderr: StdioCollector { id: nopwErr }
        onExited: code => {
            stdinEnabled = true;
            if (code !== 0 && /password is required|a password is required/i.test(nopwErr.text)) {
                root.reason = root.current.args.join(" ");
                root.askPassword = true;
                return;
            }
            root.finish(code, nopwOut.text, nopwErr.text);
        }
    }
    Process {
        id: withpw
        property string pw: ""
        stdinEnabled: true
        onStarted: { write(pw + "\n" + (root.current?.input ? root.current.input + "\n" : "")); pw = ""; stdinEnabled = false; }
        stdout: StdioCollector { id: wpOut }
        stderr: StdioCollector { id: wpErr }
        onExited: code => { stdinEnabled = true; root.finish(code, wpOut.text, wpErr.text); }
    }
}
