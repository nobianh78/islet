// Vùng "thanh tiêu đề" của cửa sổ Cài đặt: kéo để di chuyển, bấm đúp để phóng to / thu về.
import QtQuick

MouseArea {
    property real last: 0
    acceptedButtons: Qt.LeftButton
    onPressed: {
        const w = Window.window;
        const now = Date.now();
        if (now - last < 350) { last = 0; if (w) w.visibility = (w.visibility === Window.Maximized ? Window.Windowed : Window.Maximized); return; }
        last = now;
        if (w) w.startSystemMove();
    }
}
