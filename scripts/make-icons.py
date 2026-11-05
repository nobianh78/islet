#!/usr/bin/env python3
"""Sinh toàn bộ icon của Islet từ một chỗ, để cùng phong cách:

  shell/assets/icons/*.svg        icon hệ thống (nét trắng, lưới 24, nét 1.8 bo tròn)
  shell/assets/apps/*.svg         icon ứng dụng kiểu "Sắc màu" (squircle gradient, lưới 128)
  shell/assets/apps-min/<màu>/*.svg  icon kiểu "Tối giản": nền than, nét trắng, MỘT chi tiết theo màu nhấn
                                  (mỗi màu nhấn một bộ, để đổi màu nhấn là icon đổi theo)
  theme/icons/Islet/…             bộ icon cho GTK/Nautilus: thư mục, thùng rác, app (kế thừa Adwaita)

    python3 scripts/make-icons.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLYPHS = os.path.join(ROOT, "shell", "assets", "icons")
APPS = os.path.join(ROOT, "shell", "assets", "apps")
THEME = os.path.join(ROOT, "theme", "icons", "Islet")

VIOLET = "#8B7CFF"
PINK = "#FF6B97"
INK = "#07070F"
TEAL = "#5EEAD4"


def write(path, svg):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(svg.strip() + "\n")


# ============================================================================
# 1. Icon hệ thống — nét trắng, 24×24
# ============================================================================
def glyph(body, fill="none"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="{fill}" stroke="#fff" '
            f'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">{body}</svg>')


def wifi(level):
    arcs = ["M8.6 15.6a4.8 4.8 0 0 1 6.8 0", "M5.4 12.4a9.3 9.3 0 0 1 13.2 0", "M2.3 9.2a13.8 13.8 0 0 1 19.4 0"]
    out = []
    for i, d in enumerate(arcs):
        op = "" if i < level else ' opacity=".28"'
        out.append(f'<path d="{d}"{op}/>')
    out.append('<circle cx="12" cy="19" r="1.4" fill="#fff" stroke="none"/>')
    return glyph("".join(out))


SPEAKER = '<path d="M4 9.5h3l4.5-3.8v12.6L7 14.5H4a1 1 0 0 1-1-1v-3a1 1 0 0 1 1-1z" fill="#fff"/>'

GLYPH_SET = {
    # --- mạng ---
    "wifi": wifi(3),
    "wifi-2": wifi(2),
    "wifi-1": wifi(1),
    "wifi-off": glyph('<path d="M8.6 15.6a4.8 4.8 0 0 1 6.8 0" opacity=".35"/><path d="M5.4 12.4a9.3 9.3 0 0 1 4.2-2.4" opacity=".35"/>'
                      '<path d="M2.3 9.2a13.8 13.8 0 0 1 5-3.1" opacity=".35"/><path d="M14.7 10.1a9.3 9.3 0 0 1 3.9 2.3" opacity=".35"/>'
                      '<path d="M11.6 5.4a13.8 13.8 0 0 1 10.1 3.8" opacity=".35"/><path d="M4 4l16 16"/>'
                      '<circle cx="12" cy="19" r="1.4" fill="#fff" stroke="none"/>'),
    "ethernet": glyph('<rect x="3.5" y="5" width="17" height="11" rx="3"/><path d="M8 16v3.5M16 16v3.5M8 19.5h8"/>'
                      '<path d="M8 9.5v2M12 9.5v2M16 9.5v2"/>'),
    "bluetooth": glyph('<path d="M7 7.5l10 9-5 4.5v-18l5 4.5-10 9"/>'),
    # --- âm thanh ---
    "volume": glyph(SPEAKER + '<path d="M15 9.2a4 4 0 0 1 0 5.6"/><path d="M17.8 6.4a8 8 0 0 1 0 11.2"/>'),
    "volume-low": glyph(SPEAKER + '<path d="M15 9.2a4 4 0 0 1 0 5.6"/>'),
    "volume-mute": glyph(SPEAKER + '<path d="M15.5 9.5l5 5M20.5 9.5l-5 5"/>'),
    # --- nhạc ---
    "play": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M8 5.6v12.8c0 .8.9 1.3 1.6.8l10-6.4a1 1 0 0 0 0-1.6l-10-6.4c-.7-.5-1.6 0-1.6.8z" fill="#000"/></svg>',
    "pause": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#000"><rect x="6" y="5" width="4.2" height="14" rx="1.4"/><rect x="13.8" y="5" width="4.2" height="14" rx="1.4"/></svg>',
    "prev": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#fff"><rect x="4" y="5.5" width="2.4" height="13" rx="1.2"/>'
            '<path d="M19.5 6.4v11.2c0 .8-.9 1.3-1.6.8L9.6 13a1.2 1.2 0 0 1 0-2l8.3-5.4c.7-.5 1.6 0 1.6.8z"/></svg>',
    "next": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#fff"><rect x="17.6" y="5.5" width="2.4" height="13" rx="1.2"/>'
            '<path d="M4.5 6.4v11.2c0 .8.9 1.3 1.6.8l8.3-5.4a1.2 1.2 0 0 0 0-2L6.1 5.6c-.7-.5-1.6 0-1.6.8z"/></svg>',
    "music": glyph('<path d="M9 17.5V6.2l10-2.2v11.3"/><circle cx="6.5" cy="17.5" r="2.5"/><circle cx="16.5" cy="15.3" r="2.5"/>'),
    # --- hệ thống ---
    "bell": glyph('<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 1.5h-15z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>'),
    "bolt": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M13.2 2.5L5.6 13.2h5.6l-.9 8.3 7.7-10.8h-5.6z" fill="#4ADE80" stroke="#4ADE80" stroke-width="1" stroke-linejoin="round"/></svg>',
    "sun": glyph('<circle cx="12" cy="12" r="3.8"/><path d="M12 2.8v1.8M12 19.4v1.8M2.8 12h1.8M19.4 12h1.8M5.5 5.5l1.3 1.3M17.2 17.2l1.3 1.3M5.5 18.5l1.3-1.3M17.2 6.8l1.3-1.3"/>'),
    "moon": glyph('<path d="M19.5 14.2A7.8 7.8 0 1 1 9.8 4.5a6.2 6.2 0 0 0 9.7 9.7z"/>'),
    "sliders": glyph('<path d="M4 7.5h8.5M16.5 7.5H20M4 16.5h3.5M11.5 16.5H20"/><circle cx="14.5" cy="7.5" r="2.2"/><circle cx="9.5" cy="16.5" r="2.2"/>'),
    "calendar": glyph('<rect x="3.5" y="5" width="17" height="15.5" rx="3.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>'),
    "search": glyph('<circle cx="10.8" cy="10.8" r="6.3"/><path d="M15.5 15.5L20 20"/>'),
    "activity": glyph('<path d="M3 12h4l2.5-6 5 12 2.5-6h4"/>'),
    # --- nguồn ---
    "power": glyph('<path d="M12 3.5v8"/><path d="M7.2 6.6a7.5 7.5 0 1 0 9.6 0"/>'),
    "restart": glyph('<path d="M19.5 12a7.5 7.5 0 1 1-2.6-5.7"/><path d="M19.5 4v4.5H15"/>'),
    "sleep": glyph('<path d="M18.5 14.5A7.5 7.5 0 1 1 9.5 5.5a6 6 0 0 0 9 9z"/><path d="M15 4h3.5L15 8h3.5"/>'),
    "logout": glyph('<path d="M14 4.5h3.5a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H14"/><path d="M10 16.5L5.5 12 10 7.5"/><path d="M5.5 12H15"/>'),
    # --- thay emoji trong giao diện ---
    "layers": glyph('<path d="M12 3.5l8.5 4.5L12 12.5 3.5 8z"/><path d="M3.5 12L12 16.5l8.5-4.5"/><path d="M3.5 16L12 20.5l8.5-4.5"/>'),
    "sparkle": glyph('<path d="M12 3.5l2 5.5 5.5 2-5.5 2-2 5.5-2-5.5-5.5-2 5.5-2z"/><path d="M19 3.5v3M17.5 5h3" stroke-width="1.5"/>'),
    "check": glyph('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
    "check-circle": glyph('<circle cx="12" cy="12" r="8.5"/><path d="M8 12.2l2.8 2.8L16.2 9.5"/>'),
    "close": glyph('<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>'),
    "plus": glyph('<path d="M12 5v14M5 12h14"/>'),
    "download": glyph('<path d="M12 4v11"/><path d="M7.5 10.5L12 15l4.5-4.5"/><path d="M5 19.5h14"/>'),
    "refresh": glyph('<path d="M19.5 12a7.5 7.5 0 1 1-2.6-5.7"/><path d="M19.5 4v4.5H15"/>'),
    "user": glyph('<circle cx="12" cy="8.5" r="3.8"/><path d="M4.8 20a7.2 7.2 0 0 1 14.4 0"/>'),
    "headphones": glyph('<path d="M4.5 15v-3a7.5 7.5 0 0 1 15 0v3"/><rect x="3.5" y="14" width="4" height="6" rx="1.6"/><rect x="16.5" y="14" width="4" height="6" rx="1.6"/>'),
    "mouse": glyph('<rect x="7" y="3.5" width="10" height="17" rx="5"/><path d="M12 7v3"/>'),
    "keyboard": glyph('<rect x="3" y="6.5" width="18" height="11" rx="2.5"/><path d="M7 10h.01M10.5 10h.01M14 10h.01M17 10h.01M7.5 14h9"/>'),
    "phone": glyph('<rect x="7" y="3" width="10" height="18" rx="2.6"/><path d="M11 17.5h2"/>'),
    "device": glyph('<rect x="4" y="5" width="16" height="11" rx="2"/><path d="M9 19.5h6"/>'),
    "mic": glyph('<rect x="9" y="3.5" width="6" height="11" rx="3"/><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v2.5"/>'),
    "camera": glyph('<rect x="3" y="7" width="13" height="10" rx="2.4"/><path d="M16 11l5-3v8l-5-3z"/>'),
    "timer": glyph('<circle cx="12" cy="13.5" r="7"/><path d="M12 13.5V10M10 3.5h4M18.5 7l1.2-1.2"/>'),
    "record": glyph('<circle cx="12" cy="12" r="6" fill="#fff"/>'),
    "stop": glyph('<rect x="7" y="7" width="10" height="10" rx="2" fill="#fff"/>'),
    "image": glyph('<rect x="3.5" y="5" width="17" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.6"/><path d="M20.5 16l-5-5-8 8"/>'),
    "calculator": glyph('<rect x="5" y="3" width="14" height="18" rx="2.5"/><path d="M8 7h8M8.5 12h.01M12 12h.01M15.5 12h.01M8.5 16h.01M12 16h.01M15.5 16h.01"/>'),
    "arrow-right": glyph('<path d="M5 12h14M13 6l6 6-6 6"/>'),
    "lock": glyph('<rect x="5" y="10.5" width="14" height="10" rx="2.8"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/><path d="M12 14.5v2"/>'),
    "warning": glyph('<path d="M10.3 4.2L2.9 17.6a2 2 0 0 0 1.7 2.9h14.8a2 2 0 0 0 1.7-2.9L13.7 4.2a2 2 0 0 0-3.4 0z"/><path d="M12 9.5v4.5"/><circle cx="12" cy="17" r=".6" fill="#fff"/>'),
    "disk": glyph('<rect x="3.5" y="6" width="17" height="12" rx="3"/><path d="M3.5 13h17"/><circle cx="16.5" cy="15.5" r=".8" fill="#fff" stroke="none"/>'),
    "palette": glyph('<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.2 0 1.8-.8 1.8-1.7 0-.9-.6-1.3-.6-2.1 0-1 .8-1.7 1.8-1.7H17a3.5 3.5 0 0 0 3.5-3.5c0-4.4-3.8-8-8.5-8z"/>'
                     '<circle cx="7.8" cy="11" r="1.1" fill="#fff" stroke="none"/><circle cx="10.5" cy="7.5" r="1.1" fill="#fff" stroke="none"/><circle cx="15" cy="8" r="1.1" fill="#fff" stroke="none"/>'),
    "document": glyph('<path d="M6.5 3.5h7l4 4v11a2 2 0 0 1-2 2h-9a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2z"/><path d="M13.5 3.5v4h4M8.5 12.5h7M8.5 16h5"/>'),
    "code": glyph('<path d="M8.5 7.5L4 12l4.5 4.5M15.5 7.5L20 12l-4.5 4.5M13.5 5l-3 14"/>'),
    "gamepad": glyph('<path d="M7.5 7.5h9a4.5 4.5 0 0 1 4.4 5.5l-.9 4a2.5 2.5 0 0 1-4.3 1.1l-1.7-2.1h-4l-1.7 2.1A2.5 2.5 0 0 1 4 17l-.9-4a4.5 4.5 0 0 1 4.4-5.5z"/>'
                     '<path d="M8 10.5v3M6.5 12h3"/><circle cx="15.5" cy="11" r=".8" fill="#fff" stroke="none"/><circle cx="17" cy="13" r=".8" fill="#fff" stroke="none"/>'),
    "toolbox": glyph('<rect x="3.5" y="8" width="17" height="11.5" rx="2.5"/><path d="M9 8V6a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 6v2M3.5 13h17M10 13v2h4v-2"/>'),
    "pin": glyph('<path d="M9 4h6l-1 5.5 3 3H7l3-3z"/><path d="M12 12.5V20"/>'),
    "dot": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3" fill="#fff"/></svg>',
    "grid": glyph('<rect x="4" y="4" width="6.5" height="6.5" rx="2"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="2"/>'
                  '<rect x="4" y="13.5" width="6.5" height="6.5" rx="2"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="2"/>'),
    "clipboard": glyph('<rect x="5" y="4.5" width="14" height="17" rx="3"/><path d="M9 4.5V3.8A1.3 1.3 0 0 1 10.3 2.5h3.4A1.3 1.3 0 0 1 15 3.8v.7"/><path d="M8.5 11h7M8.5 15h4.5"/>'),
    # --- app (bản nét, dùng ở chỗ nhỏ) ---
    "folder": glyph('<path d="M3.5 7.5a2 2 0 0 1 2-2h4l2 2.2h7a2 2 0 0 1 2 2v7.8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/>'),
    "globe": glyph('<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17"/><path d="M12 3.5c2.5 2.6 3.6 5.4 3.6 8.5s-1.1 5.9-3.6 8.5c-2.5-2.6-3.6-5.4-3.6-8.5s1.1-5.9 3.6-8.5z"/>'),
    "terminal": glyph('<path d="M5 7.5l4.5 4.5L5 16.5"/><path d="M12.5 17h6.5"/>').replace('stroke="#fff"', f'stroke="{TEAL}"'),
    "settings": None,  # sinh ở dưới (bánh răng)
}


def gear_path(cx, cy, r_out, r_in, teeth, round_k=0.32):
    """Bánh răng: răng hình thang bo nhẹ."""
    pts = []
    for i in range(teeth):
        a0 = (i / teeth) * 2 * math.pi
        w = 2 * math.pi / teeth
        for frac, r in ((0.0, r_in), (0.18, r_in), (0.28, r_out), (0.72, r_out), (0.82, r_in)):
            a = a0 + frac * w - math.pi / 2
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + "Z"
    return d


GLYPH_SET["settings"] = glyph(f'<path d="{gear_path(12, 12, 9, 6.6, 8)}"/><circle cx="12" cy="12" r="2.8"/>')


# ============================================================================
# 2. Icon ứng dụng — squircle 128×128
# ============================================================================
def squircle(size=128, inset=6):
    """Góc bo liên tục kiểu iOS (xấp xỉ bằng bezier)."""
    s, i = size, inset
    r = (s - 2 * i) * 0.24
    k = r * 1.28  # kéo dài tiếp tuyến cho góc "mềm"
    return (f"M{i + k} {i} H{s - i - k} C{s - i - k * 0.3} {i} {s - i} {i + k * 0.3} {s - i} {i + k} "
            f"V{s - i - k} C{s - i} {s - i - k * 0.3} {s - i - k * 0.3} {s - i} {s - i - k} {s - i} "
            f"H{i + k} C{i + k * 0.3} {s - i} {i} {s - i - k * 0.3} {i} {s - i - k} "
            f"V{i + k} C{i} {i + k * 0.3} {i + k * 0.3} {i} {i + k} {i}Z")


SQ = squircle()


def app_icon(name, stops, art, shade="#000000", angle=(0, 0, 1, 1), defs=""):
    """Kiểu "tươi": nền gradient chéo rực màu, ánh sáng mềm góc trên-trái,
    ký hiệu trắng to xếp lớp kính mờ, bóng đổ lấy theo màu nền (không đen)."""
    st = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    x1, y1, x2, y2 = angle
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs>
  <linearGradient id="{name}-bg" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>
  <radialGradient id="{name}-hl" cx=".22" cy=".12" r=".75">
    <stop offset="0" stop-color="#fff" stop-opacity=".42"/><stop offset=".55" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="{name}-lo" x1="0" y1="0" x2="0" y2="1">
    <stop offset=".6" stop-color="{shade}" stop-opacity="0"/><stop offset="1" stop-color="{shade}" stop-opacity=".22"/>
  </linearGradient>
  <filter id="{name}-sh" x="-25%" y="-25%" width="150%" height="150%">
    <feDropShadow dx="0" dy="3" stdDeviation="3.5" flood-color="{shade}" flood-opacity=".35"/>
  </filter>
  {defs}
</defs>
<path d="{SQ}" fill="url(#{name}-bg)"/>
<path d="{SQ}" fill="url(#{name}-hl)"/>
<path d="{SQ}" fill="url(#{name}-lo)"/>
<g filter="url(#{name}-sh)">{art}</g>
</svg>"""


W = "#FFFFFF"

# Tệp — hai tấm thẻ thư mục chồng nhau (lớp sau kính mờ)
FILES_ART = f"""
<path d="M30 42a8 8 0 0 1 8-8h14l6 6h32a8 8 0 0 1 8 8v4H30z" fill="{W}" fill-opacity=".45"/>
<rect x="26" y="48" width="76" height="48" rx="11" fill="{W}"/>
<rect x="50" y="68" width="28" height="7" rx="3.5" fill="#B05CFF" fill-opacity=".55"/>"""

# Trình duyệt — hành tinh có vành đai + ngôi sao nhỏ
BROWSER_ART = f"""
<path d="M22 74c-6 10 4 15 22 12 14-2.4 31-8.6 46-17 15-8.4 25-17 23-23-1.6-4.6-10-5.6-21-3.6"
      fill="none" stroke="{W}" stroke-opacity=".5" stroke-width="6" stroke-linecap="round"/>
<circle cx="62" cy="64" r="27" fill="{W}"/>
<path d="M40 79c-5 7-3 10 8 9 12-1 28-7 42-15 14-8 22-15 21-19" fill="none" stroke="{W}" stroke-width="6" stroke-linecap="round"/>
<path d="M52 56a12 12 0 0 1 10-8" fill="none" stroke="#4F7BFF" stroke-opacity=".45" stroke-width="5" stroke-linecap="round"/>
<path d="M92 30l2.6 6 6 2.6-6 2.6-2.6 6-2.6-6-6-2.6 6-2.6z" fill="{W}"/>"""

# Terminal — ">_" thật dày trên ô kính mờ
TERMINAL_ART = f"""
<rect x="24" y="30" width="80" height="68" rx="16" fill="{W}" fill-opacity=".22"/>
<path d="M40 52l15 13-15 13" fill="none" stroke="{W}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M62 80h26" stroke="{W}" stroke-width="9" stroke-linecap="round"/>"""

# Cài đặt — hai công tắc gạt
SETTINGS_ART = f"""
<rect x="26" y="34" width="76" height="26" rx="13" fill="{W}" fill-opacity=".35"/>
<circle cx="46" cy="47" r="9" fill="{W}"/>
<rect x="26" y="68" width="76" height="26" rx="13" fill="{W}"/>
<circle cx="82" cy="81" r="9" fill="#FF6F7D"/>"""

# Ứng dụng — lưới 4 ô, đậm nhạt khác nhau
APPS_ART = f"""
<rect x="30" y="30" width="30" height="30" rx="10" fill="{W}"/>
<rect x="68" y="30" width="30" height="30" rx="10" fill="{W}" fill-opacity=".7"/>
<rect x="30" y="68" width="30" height="30" rx="10" fill="{W}" fill-opacity=".7"/>
<rect x="68" y="68" width="30" height="30" rx="15" fill="{W}" fill-opacity=".45"/>"""

# Trình phát video — nút play trên ô kính mờ
VIDEO_ART = f"""
<rect x="24" y="30" width="80" height="68" rx="18" fill="{W}" fill-opacity=".26"/>
<path d="M56 46.5v35a3 3 0 0 0 4.6 2.5l26-17.5a3 3 0 0 0 0-5L60.6 44a3 3 0 0 0-4.6 2.5z" fill="{W}"/>"""

# Islet — mèo trắng, mặt nạ mực
ISLET_ART = f"""
<g transform="translate(14 12) scale(.5)">
<polygon points="44,86 54,30 96,58" fill="{W}" stroke="{W}" stroke-width="10" stroke-linejoin="round"/>
<polygon points="156,86 146,30 104,58" fill="{W}" stroke="{W}" stroke-width="10" stroke-linejoin="round"/>
<polygon points="58,72 60,48 80,60" fill="{PINK}" stroke="{PINK}" stroke-width="4" stroke-linejoin="round"/>
<polygon points="142,72 140,48 120,60" fill="{PINK}" stroke="{PINK}" stroke-width="4" stroke-linejoin="round"/>
<circle cx="100" cy="112" r="66" fill="{W}"/>
<rect x="50" y="96" width="100" height="42" rx="21" fill="{INK}"/>
<circle cx="78" cy="117" r="7.5" fill="{W}"/><circle cx="122" cy="117" r="7.5" fill="{W}"/>
</g>"""

# Cửa hàng — túi mua sắm kính mờ + ngôi sao
STORE_ART = f"""
<path d="M46 48v-6a18 18 0 0 1 36 0v6" fill="none" stroke="{W}" stroke-width="7" stroke-linecap="round"/>
<path d="M30 52a6 6 0 0 1 6-6h56a6 6 0 0 1 6 6l-4 38a10 10 0 0 1-10 9H44a10 10 0 0 1-10-9z" fill="{W}" fill-opacity=".9"/>
<path d="M64 60l3.6 8 8.4 1-6.2 5.8 1.7 8.4L64 79l-7.5 4.2 1.7-8.4L52 69l8.4-1z" fill="#8B5CFF"/>"""

# Trình soạn code — cửa sổ kính mờ, ba chấm, ký hiệu </> trắng
CODE_ART = f"""
<rect x="22" y="28" width="84" height="72" rx="16" fill="{W}" fill-opacity=".22"/>
<circle cx="36" cy="40" r="3.6" fill="{W}"/><circle cx="47" cy="40" r="3.6" fill="{W}" fill-opacity=".7"/><circle cx="58" cy="40" r="3.6" fill="{W}" fill-opacity=".45"/>
<path d="M50 60l-14 12 14 12" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M78 60l14 12-14 12" fill="none" stroke="{W}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M68 56l-8 32" stroke="{W}" stroke-opacity=".75" stroke-width="7" stroke-linecap="round"/>"""

# Bộ lập trình: chữ viết tắt to, kiểu Islet (không vẽ lại logo thương hiệu)
def stack_art(mono, sub):
    size = 46 if len(mono) <= 2 else 36
    return f"""
<rect x="22" y="24" width="84" height="80" rx="20" fill="{W}" fill-opacity=".16"/>
<text x="64" y="{78 if sub else 82}" text-anchor="middle" font-family="JetBrains Mono, monospace" font-weight="800"
      font-size="{size}" fill="{W}">{mono}</text>
""" + (f'<text x="64" y="96" text-anchor="middle" font-family="Be Vietnam Pro, sans-serif" font-weight="700" font-size="11" fill="{W}" fill-opacity=".85">{sub}</text>' if sub else "")

STACKS = {
    "stack-ai":     ("AI",  "agents",      [(0, "#FF6FB5"), (.5, "#B65CFF"), (1, "#5B8CFF")], "#5A1FB8"),
    "stack-web":    ("JS",  "node · npm",  [(0, "#FFD45C"), (1, "#FF9F43")], "#9A5A00"),
    "stack-python": ("Py",  "pip · uv",    [(0, "#4BA3FF"), (1, "#6D4AFF")], "#2A2F9A"),
    "stack-cpp":    ("C++", "gcc · cmake", [(0, "#5B8CFF"), (1, "#2EE6D6")], "#1E3A9A"),
    "stack-rust":   ("Rs",  "rustup",      [(0, "#FF8A5C"), (1, "#C2410C")], "#7A2A0A"),
    "stack-go":     ("Go",  "go · gopls",  [(0, "#4BE3E8"), (1, "#0EA5B7")], "#0B5E6B"),
    "stack-java":   ("Jv",  "jdk · gradle",[(0, "#FF6B6B"), (1, "#FF9F43")], "#8A1F1F"),
    "stack-docker": ("Dk",  "docker",      [(0, "#38BDF8"), (1, "#2563EB")], "#143D8A"),
    "stack-git":    ("Git", "gh · lazygit",[(0, "#FF7A59"), (1, "#E11D48")], "#7A1430"),
    "stack-php":    ("Php", "composer",    [(0, "#A99CFF"), (1, "#6D4AFF")], "#3B1FA0"),
    "stack-dotnet": (".N",  "dotnet",      [(0, "#B65CFF"), (1, "#6D28D9")], "#3B1478"),
}

APP_SET = {
    "store":    app_icon("store", [(0, "#4BE3E8"), (.5, "#5B8CFF"), (1, "#8B5CFF")], STORE_ART, shade="#2A2F9A"),
    "files":    app_icon("files", [(0, "#8F6BFF"), (.55, "#B65CFF"), (1, "#FF6FB5")], FILES_ART, shade="#5A1FB8"),
    "browser":  app_icon("br", [(0, "#2EE6D6"), (.5, "#3B8BFF"), (1, "#7B5CFF")], BROWSER_ART, shade="#1E3A9A"),
    "terminal": app_icon("term", [(0, "#B8F55A"), (.55, "#34D399"), (1, "#10B9C9")], TERMINAL_ART, shade="#0B6B5E"),
    "settings": app_icon("set", [(0, "#FFC46B"), (.55, "#FF8A5C"), (1, "#FF5C8A")], SETTINGS_ART, shade="#B23A2E"),
    "apps":     app_icon("apps", [(0, "#4BE3E8"), (.5, "#8B7CFF"), (1, "#F472B6")], APPS_ART, shade="#3B2A9A"),
    "video":    app_icon("vid", [(0, "#FF5C7A"), (.55, "#FF6B5C"), (1, "#FF9F43")], VIDEO_ART, shade="#A1202F"),
    "code":     app_icon("code", [(0, "#38BDF8"), (.5, "#3B6BFF"), (1, "#7B5CFF")], CODE_ART, shade="#1E2F9A"),
    "islet":    app_icon("islet", [(0, "#A78BFA"), (.55, "#8B7CFF"), (1, "#6D4AFF")], ISLET_ART, shade="#3B1FA0"),
}


# ============================================================================
# 2b. Kiểu "Tối giản": nền than đồng nhất, ký hiệu trắng, một chi tiết màu nhấn
# ============================================================================
ACCENTS = {"violet": "#8B7CFF", "blue": "#5B8CFF", "teal": "#2EC4B6", "green": "#34C77B",
           "amber": "#FF9F43", "pink": "#FF6B97", "red": "#FF5F57"}
WH = "#F4F4F8"

def min_icon(name, art):
    """art: hàm(A) → SVG ký hiệu, A là màu nhấn."""
    def build(A):
        return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
<defs>
  <linearGradient id="{name}-m" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2B2B36"/><stop offset="1" stop-color="#17171E"/></linearGradient>
  <linearGradient id="{name}-e" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset=".35" stop-color="#fff" stop-opacity=".05"/><stop offset="1" stop-color="#fff" stop-opacity=".03"/></linearGradient>
  <radialGradient id="{name}-g" cx=".5" cy=".55" r=".55"><stop offset="0" stop-color="{A}" stop-opacity=".16"/><stop offset="1" stop-color="{A}" stop-opacity="0"/></radialGradient>
</defs>
<path d="{SQ}" fill="url(#{name}-m)"/>
<path d="{SQ}" fill="url(#{name}-g)"/>
<path d="{SQ}" fill="none" stroke="url(#{name}-e)" stroke-width="1.6"/>
{art(A)}
</svg>"""
    return build

MIN_ART = {
    # Tệp — thẻ thư mục, vạch nhấn trên mặt trước
    "files": lambda A: f"""
<path d="M30 44a7 7 0 0 1 7-7h13l6 6h35a7 7 0 0 1 7 7v3H30z" fill="{WH}" fill-opacity=".38"/>
<rect x="27" y="50" width="74" height="44" rx="10" fill="{WH}"/>
<rect x="38" y="60" width="22" height="6" rx="3" fill="{A}"/>""",
    # Trình duyệt — quả cầu trắng, vành đai màu nhấn
    "browser": lambda A: f"""
<circle cx="64" cy="64" r="25" fill="{WH}"/>
<path d="M30 80c-4 7 3 10 16 8 12-2 27-8 40-16 13-8 20-16 18-21-1.4-3.4-7-4.4-15-3" fill="none" stroke="{A}" stroke-width="6" stroke-linecap="round"/>""",
    # Terminal — ">" trắng, con trỏ "_" màu nhấn
    "terminal": lambda A: f"""
<path d="M38 50l16 14-16 14" fill="none" stroke="{WH}" stroke-width="8.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M62 80h28" stroke="{A}" stroke-width="8.5" stroke-linecap="round"/>""",
    # Cài đặt — hai công tắc, một núm màu nhấn
    "settings": lambda A: f"""
<rect x="28" y="38" width="72" height="22" rx="11" fill="{WH}" fill-opacity=".22"/>
<circle cx="45" cy="49" r="8" fill="{WH}"/>
<rect x="28" y="68" width="72" height="22" rx="11" fill="{WH}" fill-opacity=".22"/>
<circle cx="83" cy="79" r="8" fill="{A}"/>""",
    # Ứng dụng — lưới 4 ô, một ô màu nhấn
    "apps": lambda A: f"""
<rect x="32" y="32" width="28" height="28" rx="9" fill="{WH}"/>
<rect x="68" y="32" width="28" height="28" rx="9" fill="{WH}" fill-opacity=".55"/>
<rect x="32" y="68" width="28" height="28" rx="9" fill="{WH}" fill-opacity=".55"/>
<rect x="68" y="68" width="28" height="28" rx="14" fill="{A}"/>""",
    # Trình phát video — khung trắng mờ, nút play màu nhấn
    "video": lambda A: f"""
<rect x="26" y="34" width="76" height="60" rx="16" fill="none" stroke="{WH}" stroke-opacity=".9" stroke-width="6"/>
<path d="M57 50v28a2.5 2.5 0 0 0 3.8 2.1l21-14a2.5 2.5 0 0 0 0-4.2l-21-14A2.5 2.5 0 0 0 57 50z" fill="{A}"/>""",
    # Cửa hàng — túi trắng, ngôi sao màu nhấn
    "store": lambda A: f"""
<path d="M48 50v-6a16 16 0 0 1 32 0v6" fill="none" stroke="{WH}" stroke-width="6.5" stroke-linecap="round"/>
<path d="M32 54a6 6 0 0 1 6-6h52a6 6 0 0 1 6 6l-3.5 34a10 10 0 0 1-10 9H45.5a10 10 0 0 1-10-9z" fill="{WH}"/>
<path d="M64 61l3.4 7.4 8 1-5.9 5.5 1.6 8L64 79l-7.1 3.9 1.6-8-5.9-5.5 8-1z" fill="{A}"/>""",
    # Trình soạn code — ba chấm (chấm đầu màu nhấn) + </>
    "code": lambda A: f"""
<circle cx="38" cy="38" r="4" fill="{A}"/><circle cx="50" cy="38" r="4" fill="{WH}" fill-opacity=".5"/><circle cx="62" cy="38" r="4" fill="{WH}" fill-opacity=".3"/>
<path d="M50 58l-14 13 14 13" fill="none" stroke="{WH}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M78 58l14 13-14 13" fill="none" stroke="{WH}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M68 54l-8 34" stroke="{A}" stroke-width="7" stroke-linecap="round"/>""",
    # Islet — mèo trắng, mặt nạ mực, mắt màu nhấn
    "islet": lambda A: f"""
<g transform="translate(14 12) scale(.5)">
<polygon points="44,86 54,30 96,58" fill="{WH}" stroke="{WH}" stroke-width="10" stroke-linejoin="round"/>
<polygon points="156,86 146,30 104,58" fill="{WH}" stroke="{WH}" stroke-width="10" stroke-linejoin="round"/>
<circle cx="100" cy="112" r="66" fill="{WH}"/>
<rect x="50" y="96" width="100" height="42" rx="21" fill="{INK}"/>
<circle cx="78" cy="117" r="7.5" fill="{A}"/><circle cx="122" cy="117" r="7.5" fill="{A}"/>
</g>""",
}

def min_stack(mono, sub):
    size = 44 if len(mono) <= 2 else 34
    return lambda A: f"""
<text x="64" y="74" text-anchor="middle" font-family="JetBrains Mono, monospace" font-weight="800" font-size="{size}" fill="{WH}">{mono}</text>
<rect x="50" y="84" width="28" height="5" rx="2.5" fill="{A}"/>
<text x="64" y="104" text-anchor="middle" font-family="Be Vietnam Pro, sans-serif" font-weight="600" font-size="10" fill="{WH}" fill-opacity=".5">{sub}</text>"""


# ============================================================================
# 3. Bộ icon Islet cho GTK: thư mục (64×64) + thùng rác + app
# ============================================================================
EMBLEMS = {
    "folder": "",
    "user-home": '<path d="M24 40l8-7 8 7v8h-5v-5h-6v5h-5z"/>',
    "user-desktop": '<rect x="22" y="33" width="20" height="13" rx="2"/><path d="M28 50h8M32 46v4"/>',
    "folder-documents": '<path d="M26 31h8l5 5v13a1.5 1.5 0 0 1-1.5 1.5h-11.5a1.5 1.5 0 0 1-1.5-1.5v-16.5a1.5 1.5 0 0 1 1.5-1.5z"/><path d="M28.5 41h7M28.5 45h5"/>',
    "folder-download": '<path d="M32 31v13M26.5 39l5.5 5.5 5.5-5.5M25 50h14"/>',
    "folder-music": '<path d="M29 47V34l10-2v12"/><circle cx="26.5" cy="47" r="2.5"/><circle cx="36.5" cy="44.5" r="2.5"/>',
    "folder-pictures": '<rect x="22" y="32" width="20" height="16" rx="3"/><circle cx="28" cy="37.5" r="2"/><path d="M42 44l-5-5-9 9"/>',
    "folder-videos": '<rect x="22" y="32" width="20" height="16" rx="3"/><path d="M30 36.5v7l5.5-3.5z" fill="#fff"/>',
    "folder-templates": '<rect x="23" y="32" width="18" height="16" rx="2.5"/><path d="M23 37.5h18M29.5 37.5V48"/>',
    "folder-publicshare": '<circle cx="37" cy="34.5" r="2.5"/><circle cx="27" cy="40" r="2.5"/><circle cx="37" cy="45.5" r="2.5"/><path d="M29.3 38.8l5.4-3M29.3 41.2l5.4 3"/>',
}


def folder_svg(emblem, top="#454554", bot="#30303C", back="#24242D", accent=VIOLET):
    em = (f'<g fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" '
          f'opacity=".9">{emblem}</g>') if emblem else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs>
  <linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>
  <linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{back}"/><stop offset="1" stop-color="#1B1B22"/></linearGradient>
  <filter id="s" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="1.5" stdDeviation="1.5" flood-color="#000000" flood-opacity=".35"/></filter>
</defs>
<path d="M6 15a4 4 0 0 1 4-4h13.5a3 3 0 0 1 2.2 1l3.6 4H54a4 4 0 0 1 4 4v6H6z" fill="url(#b)"/>
<path d="M33 16h21" stroke="#fff" stroke-opacity=".25" stroke-width="1"/>
<g filter="url(#s)"><rect x="4" y="22" width="56" height="34" rx="6" fill="url(#f)"/></g>
<path d="M9 23.2h46" stroke="#fff" stroke-opacity=".22" stroke-width="1.2" stroke-linecap="round"/>
<rect x="10" y="27" width="12" height="3" rx="1.5" fill="{accent}"/>
<g transform="translate(0 0)">{em}</g>
</svg>'''


def trash_svg(full):
    paper = ('<path d="M24 20l4-6 6 4-2 4z" fill="#fff" opacity=".9"/><path d="M33 19l7-4 2 6z" fill="#FFD0DF"/>' if full else "")
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs>
  <linearGradient id="t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F3F1FF"/><stop offset="1" stop-color="#C9C2F5"/></linearGradient>
  <linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#A99CFF"/><stop offset="1" stop-color="#7C6BFF"/></linearGradient>
</defs>
{paper}
<path d="M15 24h34l-3.2 30a4 4 0 0 1-4 3.6H22.2a4 4 0 0 1-4-3.6z" fill="url(#t)"/>
<path d="M25 30v20M32 30v20M39 30v20" stroke="#8B7CFF" stroke-opacity=".45" stroke-width="2.4" stroke-linecap="round"/>
<rect x="11" y="18" width="42" height="7" rx="3.5" fill="url(#l)"/>
<path d="M27 18v-2.5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2V18" fill="none" stroke="#7C6BFF" stroke-width="2.4"/>
</svg>'''


INDEX_THEME = """[Icon Theme]
Name=Islet
Comment=Icon của Islet: thư mục, thùng rác và ứng dụng theo màu logo
Inherits=Adwaita,hicolor
Directories=scalable/places,scalable/apps

[scalable/places]
Size=64
MinSize=16
MaxSize=512
Type=Scalable
Context=Places

[scalable/apps]
Size=128
MinSize=16
MaxSize=512
Type=Scalable
Context=Applications
"""


for _n, (_m, _sub, _st, _sh) in STACKS.items():
    APP_SET[_n] = app_icon(_n, _st, stack_art(_m, _sub), shade=_sh)


def main():
    for name, svg in GLYPH_SET.items():
        write(os.path.join(GLYPHS, name + ".svg"), svg)
    for name, svg in APP_SET.items():
        write(os.path.join(APPS, name + ".svg"), svg)

    for _n, (_m, _sub, _st, _sh) in STACKS.items():
        MIN_ART[_n] = min_stack(_m, _sub)
    MIN_ART["_tile"] = lambda A: ""          # ô trống, đặt icon thật của app lạ lên trên
    MINS = {n: min_icon(n, a) for n, a in MIN_ART.items()}
    for acc, col in ACCENTS.items():
        for name, build in MINS.items():
            write(os.path.join(ROOT, "shell", "assets", "apps-min", acc, name + ".svg"), build(col))

    places = os.path.join(THEME, "scalable", "places")
    for name, em in EMBLEMS.items():
        write(os.path.join(places, name + ".svg"), folder_svg(em))
    write(os.path.join(places, "user-trash.svg"), trash_svg(False))
    write(os.path.join(places, "user-trash-full.svg"), trash_svg(True))

    apps = os.path.join(THEME, "scalable", "apps")
    for theme_name, app in (("org.gnome.Nautilus", "files"), ("firefox", "browser"), ("kitty", "terminal"),
                            ("org.gnome.Settings", "settings"), ("islet", "islet"), ("mpv", "video"),
                            ("islet-store", "store"), ("code-oss", "code"), ("com.visualstudio.code.oss", "code")):
        write(os.path.join(apps, theme_name + ".svg"), MINS[app](VIOLET) if app in MINS else APP_SET[app])
    write(os.path.join(THEME, "index.theme"), INDEX_THEME)

    print(f"{len(GLYPH_SET)} icon hệ thống, {len(APP_SET)} icon app, {len(EMBLEMS) + 2} icon thư mục/thùng rác")


if __name__ == "__main__":
    main()
