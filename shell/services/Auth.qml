pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Kiểm tra mật khẩu tài khoản MỘT lần qua PAM trước khi đưa cho sudo.
// Lý do: sudo -S gặp mật khẩu sai sẽ đọc tiếp các dòng sau làm lần thử 2, 3 → một lần gõ sai bị
// tính 3 lần và faillock khoá tài khoản 10 phút. Qua đây một lần sai chỉ tính đúng một lần.
//   Auth.verify(pw, ok => { ... })
Singleton {
    id: root
    property var pending: null       // { pw, cb }
    readonly property bool busy: pending !== null

    function verify(pw, cb) {
        if (pending) { cb(false); return; }
        pending = { pw: pw, cb: cb };
        if (!pam.start()) { const p = pending; pending = null; p.cb(false); }
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER") || ""
        onPamMessage: { if (responseRequired) respond(root.pending?.pw ?? ""); }
        onCompleted: result => { const p = root.pending; root.pending = null; p?.cb(result === PamResult.Success); }
        onError: err => { const p = root.pending; root.pending = null; p?.cb(false); }
    }
}
