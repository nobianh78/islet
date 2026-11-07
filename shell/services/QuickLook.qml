pragma Singleton
import QtQuick
import Quickshell

// Xem nhanh (Quick Look) một file bằng GNOME Sushi — cũng là thứ mở ra khi bấm Space trong Files.
// Ảnh, PDF, video, nhạc, code/văn bản (tô màu cú pháp), font… Gọi lại khi đang xem = đóng.
Singleton {
    function show(path) {
        if (!path) return;
        const uri = path.startsWith("file://") ? path : "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.gnome.NautilusPreviewer",
            "--object-path", "/org/gnome/NautilusPreviewer", "--method", "org.gnome.NautilusPreviewer2.ShowFile", uri, "", "true", ""]);    // (uri, cửa sổ cha, đóng nếu đang xem, activation token)
    }
}
