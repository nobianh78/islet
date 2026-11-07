pragma Singleton
import QtQuick
import Quickshell
import "../theme"

// Đồng hồ hệ thống + định dạng ngày giờ (tiếng Anh).
Singleton {
    id: root

    readonly property date now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property var dayLong: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var dayShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthLong: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var monthShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    // "Thursday, November 5"
    function longDate(d) { return dayLong[d.getDay()] + ", " + monthLong[d.getMonth()] + " " + d.getDate(); }

    readonly property string time: (Prefs.clock24 ? pad(now.getHours()) : String((now.getHours() + 11) % 12 + 1)) + ":" + pad(now.getMinutes())
        + (Prefs.clockSeconds ? ":" + pad(now.getSeconds()) : "") + (Prefs.clock24 ? "" : (now.getHours() < 12 ? " AM" : " PM"))
    // "Thu, Nov 5"
    readonly property string dateShort: dayShort[now.getDay()] + ", " + monthShort[now.getMonth()] + " " + now.getDate()
    // "THURSDAY" / "November 5" (cột ngày trên island thu gọn)
    readonly property string weekdayUpper: dayLong[now.getDay()].toUpperCase()
    readonly property string dayMonth: monthLong[now.getMonth()] + " " + now.getDate()
    readonly property string dateLong: longDate(now)
}
