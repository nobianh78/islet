pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// Thời tiết cho widget màn hình nền — Open-Meteo (miễn phí, không cần khoá, không cần tài khoản).
// Nơi: Prefs.weatherCity, để trống = đoán theo múi giờ của máy (Asia/Ho_Chi_Minh → Ho Chi Minh).
// Cập nhật mỗi 30 phút, chỉ khi có widget thời tiết.
Singleton {
    id: root

    property bool active: false
    property string place: ""
    property real temp: NaN
    property real feels: NaN
    property int code: -1
    property bool day: true
    property int humidity: 0
    property real wind: 0
    property var daily: []               // [{ date, max, min, code }]
    property string error: ""
    property double updated: 0

    readonly property string city: Prefs.weatherCity || tzCity
    property string tzCity: ""
    Process {
        running: true
        command: ["sh", "-c", "readlink /etc/localtime | sed 's|.*/zoneinfo/||'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const z = text.trim().split("/").pop() || "";
                root.tzCity = z.replace(/_/g, " ");
            }
        }
    }

    // mã thời tiết WMO → [chữ, icon ngày, icon đêm]
    function info(c) {
        if (c === 0) return ["Clear", "sun", "moon"];
        if (c <= 2) return ["Partly cloudy", "cloud", "cloud"];
        if (c === 3) return ["Cloudy", "cloud", "cloud"];
        if (c === 45 || c === 48) return ["Fog", "fog", "fog"];
        if (c >= 51 && c <= 57) return ["Drizzle", "rain", "rain"];
        if (c >= 61 && c <= 67) return ["Rain", "rain", "rain"];
        if (c >= 71 && c <= 77) return ["Snow", "snow", "snow"];
        if (c >= 80 && c <= 82) return ["Showers", "rain", "rain"];
        if (c === 85 || c === 86) return ["Snow showers", "snow", "snow"];
        if (c >= 95) return ["Thunderstorm", "storm", "storm"];
        return ["—", "cloud", "cloud"];
    }
    function label(c) { return info(c)[0]; }
    function icon(c, isDay) { return info(c)[isDay === false ? 2 : 1]; }

    onCityChanged: if (active) fetch()
    onActiveChanged: if (active && Date.now() - updated > 25 * 60000) fetch()
    Timer { interval: 30 * 60000; repeat: true; running: root.active; onTriggered: root.fetch() }
    Timer { id: retry; interval: 120000; onTriggered: root.fetch() }

    function fetch() {
        if (!city || proc.running) return;
        proc.command = ["python3", "-c", root.script, city];
        proc.running = true;
    }
    // một lần chạy: tìm toạ độ của nơi đó rồi lấy dự báo
    readonly property string script: "
import json, sys, urllib.parse, urllib.request
def get(u):
    with urllib.request.urlopen(urllib.request.Request(u, headers={'User-Agent': 'Islet'}), timeout=12) as r:
        return json.load(r)
q = sys.argv[1]
g = get('https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&name=' + urllib.parse.quote(q)).get('results') or []
if not g:
    print(json.dumps({'error': 'Place not found'})); sys.exit()
p = g[0]
f = get('https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&timezone=auto&forecast_days=5'
        '&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m'
        '&daily=temperature_2m_max,temperature_2m_min,weather_code' % (p['latitude'], p['longitude']))
c, d = f['current'], f['daily']
print(json.dumps({'place': p.get('name', q), 'temp': c['temperature_2m'], 'feels': c['apparent_temperature'], 'code': c['weather_code'],
    'day': bool(c['is_day']), 'humidity': c['relative_humidity_2m'], 'wind': c['wind_speed_10m'],
    'daily': [{'date': d['time'][i], 'max': d['temperature_2m_max'][i], 'min': d['temperature_2m_min'][i], 'code': d['weather_code'][i]} for i in range(len(d['time']))]}))
"
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                if (!d) { root.error = "Can't reach the weather service"; retry.restart(); return; }
                if (d.error) { root.error = d.error; return; }
                root.error = "";
                root.place = d.place; root.temp = d.temp; root.feels = d.feels; root.code = d.code; root.day = d.day;
                root.humidity = d.humidity; root.wind = d.wind; root.daily = d.daily; root.updated = Date.now();
            }
        }
    }
}
