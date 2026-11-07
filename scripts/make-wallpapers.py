#!/usr/bin/env python3
"""Vẽ bộ hình nền riêng của Islet → theme/wallpapers/*.jpg (4K, 3840×2160).

    python3 scripts/make-wallpapers.py            # vẽ tất cả
    python3 scripts/make-wallpapers.py lagoon     # vẽ một hình
    ISLET_WP_SCALE=0.25 python3 …                 # bản nhỏ để xem nhanh

Chỉ cần pycairo + GdkPixbuf (lưu JPEG). Mọi hình đều có hạt nhiễu nhẹ để gradient không bị vằn.
"""
import math, os, random, sys
import cairo
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.environ.get("ISLET_WP_OUT") or os.path.join(ROOT, "theme", "wallpapers")
S = float(os.environ.get("ISLET_WP_SCALE", "1"))
W, H = int(3840 * S), int(2160 * S)


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(lerp(x, y, t) for x, y in zip(c1, c2))


def glow(cr, x, y, r, color, a):
    """Quầng sáng mềm (thay cho blur)."""
    g = cairo.RadialGradient(x, y, 0, x, y, r)
    c = hexc(color)
    for t, k in [(0, 1), (0.25, 0.62), (0.5, 0.28), (0.75, 0.08), (1, 0)]:
        g.add_color_stop_rgba(t, c[0], c[1], c[2], a * k)
    cr.set_source(g)
    cr.arc(x, y, r, 0, 2 * math.pi)
    cr.fill()


def vgrad(cr, stops, x0=0, y0=0, x1=0, y1=None):
    g = cairo.LinearGradient(x0, y0, x1, H if y1 is None else y1)
    for t, c in stops:
        g.add_color_stop_rgba(t, *hexc(c))
    cr.set_source(g)
    cr.paint()


def grain(cr, amount=0.035):
    """Hạt nhiễu lặp lại (ô 256 px) phủ lên toàn hình."""
    n = 256
    tile = cairo.ImageSurface(cairo.FORMAT_ARGB32, n, n)
    buf = tile.get_data()
    rnd = random.Random(7)
    stride = tile.get_stride()
    for y in range(n):
        for x in range(n):
            v = rnd.randint(0, 255)
            a = int(255 * amount)
            p = int(v * amount)          # premultiplied
            i = y * stride + x * 4
            buf[i:i + 4] = bytes((p, p, p, a))
    tile.mark_dirty()
    pat = cairo.SurfacePattern(tile)
    pat.set_extend(cairo.EXTEND_REPEAT)
    cr.save()
    cr.set_operator(cairo.OPERATOR_OVER)
    cr.set_source(pat)
    cr.paint_with_alpha(0.55)
    # một lớp tối nhẹ ngẫu nhiên nữa để hạt không chỉ sáng lên
    cr.set_operator(cairo.OPERATOR_MULTIPLY)
    cr.set_source(pat)
    cr.paint_with_alpha(0.25)
    cr.restore()


def vignette(cr, k=0.55):
    g = cairo.RadialGradient(W / 2, H / 2, min(W, H) * 0.35, W / 2, H / 2, max(W, H) * 0.75)
    g.add_color_stop_rgba(0, 0, 0, 0, 0)
    g.add_color_stop_rgba(1, 0, 0, 0, k)
    cr.set_source(g)
    cr.paint()


def cat(cr, cx, cy, size, body="#8B7CFF", inner="#FF6B97", visor="#07070F", eye="#FFFFFF", shade=True):
    """Linh vật Islet (theo shell/assets/brand/cat.svg, hệ toạ độ 200×200)."""
    k = size / 200.0
    cr.save()
    cr.translate(cx - 100 * k, cy - 110 * k)
    cr.scale(k, k)
    cr.set_line_join(cairo.LINE_JOIN_ROUND)

    def poly(pts, fill, stroke_w):
        cr.move_to(*pts[0])
        for p in pts[1:]:
            cr.line_to(*p)
        cr.close_path()
        cr.set_source_rgba(*hexc(fill))
        cr.fill_preserve()
        cr.set_line_width(stroke_w)
        cr.stroke()

    poly([(44, 86), (54, 30), (96, 58)], body, 10)
    poly([(156, 86), (146, 30), (104, 58)], body, 10)
    poly([(58, 72), (60, 48), (80, 60)], inner, 4)
    poly([(142, 72), (140, 48), (120, 60)], inner, 4)
    # thân: gradient nhẹ cho có khối
    g = cairo.RadialGradient(80, 80, 10, 100, 112, 80)
    b = hexc(body)
    g.add_color_stop_rgba(0, *mix(b, (1, 1, 1, 1), 0.28))
    g.add_color_stop_rgba(1, *mix(b, (0, 0, 0, 1), 0.12 if shade else 0))
    cr.set_source(g)
    cr.arc(100, 112, 66, 0, 2 * math.pi)
    cr.fill()
    # kính che mắt
    r = 21
    x, y, w, h = 50, 96, 100, 42
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, math.pi / 2)
    cr.arc(x + r, y + r, r, math.pi / 2, 3 * math.pi / 2)
    cr.close_path()
    cr.set_source_rgba(*hexc(visor))
    cr.fill()
    for ex in (78, 122):
        glow(cr, ex, 117, 22, "#FFFFFF", 0.35)
        cr.set_source_rgba(*hexc(eye))
        cr.arc(ex, 117, 7.5, 0, 2 * math.pi)
        cr.fill()
    # vệt sáng trên đầu
    cr.set_source_rgba(1, 1, 1, 0.16)
    cr.save()
    cr.translate(78, 70)
    cr.scale(1.8, 1)
    cr.arc(0, 0, 9, 0, 2 * math.pi)
    cr.restore()
    cr.fill()
    cr.restore()


def ribbon(cr, pts_top, thickness, c1, c2, a1, a2, x0, x1):
    """Dải lụa: đường cong trên + đường cong dưới lệch theo độ dày, tô gradient ngang."""
    cr.move_to(*pts_top[0])
    for i in range(1, len(pts_top) - 2, 3):
        cr.curve_to(*pts_top[i], *pts_top[i + 1], *pts_top[i + 2])
    bottom = [(x, y + thickness * (0.6 + 0.4 * math.sin(i * 1.3))) for i, (x, y) in enumerate(pts_top)][::-1]
    cr.line_to(*bottom[0])
    for i in range(1, len(bottom) - 2, 3):
        cr.curve_to(*bottom[i], *bottom[i + 1], *bottom[i + 2])
    cr.close_path()
    g = cairo.LinearGradient(x0, 0, x1, 0)
    g.add_color_stop_rgba(0, *hexc(c1, a1))
    g.add_color_stop_rgba(0.5, *mix(hexc(c1, a1), hexc(c2, a2), 0.5))
    g.add_color_stop_rgba(1, *hexc(c2, a2))
    cr.set_source(g)
    cr.fill()


def wave_pts(y, amp, phase, freq=1.0, n=13):
    pts = []
    for i in range(n):
        x = -0.1 * W + 1.2 * W * i / (n - 1)
        pts.append((x, y + amp * math.sin(phase + freq * i * 0.75)))
    return pts


# ----------------------------------------------------------------------------- hình nền

def islet(cr):
    """Mặc định: chú mèo Islet trên mặt hồ đêm, sóng tròn lan ra như một hòn đảo nhỏ."""
    vgrad(cr, [(0, "#0C0A1F"), (0.55, "#120E2C"), (1, "#07060F")])
    glow(cr, W * 0.5, H * 0.56, H * 0.95, "#5B4BFF", 0.55)
    glow(cr, W * 0.18, H * 0.15, H * 0.7, "#FF4F8B", 0.22)
    glow(cr, W * 0.86, H * 0.9, H * 0.75, "#14B8A6", 0.20)
    cx, cy = W * 0.5, H * 0.585
    # sóng tròn (elip dẹt) quanh "đảo"
    for i in range(14):
        rx = H * (0.20 + i * 0.075)
        ry = rx * 0.22
        a = 0.20 * (1 - i / 14) ** 1.4
        cr.save()
        cr.translate(cx, cy + H * 0.13)
        cr.scale(1, ry / rx)
        cr.arc(0, 0, rx, 0, 2 * math.pi)
        cr.restore()
        cr.set_source_rgba(0.72, 0.66, 1, a)
        cr.set_line_width(max(1, H * 0.0022))
        cr.stroke()
    # bóng phản chiếu dưới nước
    cr.save()
    cr.translate(0, (cy + H * 0.13) * 2)
    cr.scale(1, -1)
    cr.push_group()
    cat(cr, cx, cy - H * 0.03, H * 0.30)
    cr.pop_group_to_source()
    cr.paint_with_alpha(0.10)
    cr.restore()
    glow(cr, cx, cy - H * 0.02, H * 0.36, "#8B7CFF", 0.45)
    cat(cr, cx, cy - H * 0.03, H * 0.30)
    vignette(cr, 0.5)


def lagoon(cr):
    """Những dải lụa xanh ngọc → tím trôi chéo màn hình."""
    vgrad(cr, [(0, "#04121A"), (0.6, "#071A2A"), (1, "#0A0A1C")])
    glow(cr, W * 0.75, H * 0.25, H * 0.9, "#06B6D4", 0.30)
    glow(cr, W * 0.2, H * 0.85, H * 0.9, "#6D4AFF", 0.30)
    rnd = random.Random(3)
    cols = [("#14B8A6", "#2563EB"), ("#22D3EE", "#6D4AFF"), ("#2EC4B6", "#8B7CFF"), ("#0EA5B7", "#A855F7")]
    for i in range(26):
        t = i / 25
        y = lerp(H * 0.15, H * 0.95, t) - W * 0.0
        pts = wave_pts(y, H * (0.10 + 0.05 * math.sin(i)), i * 0.33, 0.9)
        # nghiêng chéo
        pts = [(x, yy - (x / W - 0.5) * H * 0.45) for x, yy in pts]
        c1, c2 = cols[i % len(cols)]
        a = 0.05 + 0.13 * math.exp(-((t - 0.5) ** 2) / 0.06)
        ribbon(cr, pts, H * (0.03 + 0.05 * rnd.random()), c1, c2, a, a * 0.8, 0, W)
    # một sợi sáng mảnh
    for i in range(3):
        pts = wave_pts(H * (0.5 + i * 0.06), H * 0.12, 1.2 + i * 0.4, 0.9)
        pts = [(x, yy - (x / W - 0.5) * H * 0.45) for x, yy in pts]
        cr.move_to(*pts[0])
        for j in range(1, len(pts) - 2, 3):
            cr.curve_to(*pts[j], *pts[j + 1], *pts[j + 2])
        cr.set_source_rgba(0.75, 0.97, 1, 0.35 - i * 0.1)
        cr.set_line_width(H * 0.0016)
        cr.stroke()
    vignette(cr, 0.45)


def dusk(cr):
    """Hoàng hôn trên quần đảo: trời hồng cam → tím, mặt trời và các lớp đảo phẳng."""
    vgrad(cr, [(0, "#1B1036"), (0.35, "#4A1F5C"), (0.55, "#B8456A"), (0.66, "#FF8A5C"), (0.67, "#2A1840"), (1, "#0D0918")])
    horizon = H * 0.665
    # mặt trời
    sx, sy, sr = W * 0.62, horizon - H * 0.07, H * 0.13
    glow(cr, sx, sy, sr * 4.2, "#FF9F43", 0.45)
    g = cairo.LinearGradient(0, sy - sr, 0, sy + sr)
    g.add_color_stop_rgba(0, *hexc("#FFE3A3"))
    g.add_color_stop_rgba(1, *hexc("#FF6B5C"))
    cr.save()
    cr.rectangle(0, 0, W, horizon)
    cr.clip()
    cr.set_source(g)
    cr.arc(sx, sy, sr, 0, 2 * math.pi)
    cr.fill()
    # sọc cắt ngang mặt trời (retro)
    for i in range(5):
        y = sy + sr * (0.15 + i * 0.17)
        cr.rectangle(sx - sr, y, sr * 2, sr * (0.035 + i * 0.018))
    cr.set_source_rgba(*hexc("#B8456A"))
    cr.fill()
    cr.restore()
    # các lớp đảo (xa → gần)
    layers = [("#5A2A63", 0.040, 0.30, 11), ("#3D1F52", 0.065, 0.22, 5), ("#26163D", 0.10, 0.12, 17)]
    for col, amp, base_off, seed in layers:
        rnd = random.Random(seed)
        cr.move_to(-10, horizon + 2)
        x = -10
        while x < W + 10:
            w = W * (0.10 + rnd.random() * 0.22)
            h = H * amp * (0.4 + rnd.random())
            if rnd.random() < 0.55:
                cr.curve_to(x + w * 0.25, horizon - h, x + w * 0.75, horizon - h, x + w, horizon + 2)
            else:
                cr.line_to(x + w, horizon + 2)
            x += w
        cr.line_to(W + 10, horizon + 2)
        cr.close_path()
        cr.set_source_rgba(*hexc(col))
        cr.fill()
    # mặt nước + vệt phản chiếu
    g = cairo.LinearGradient(0, horizon, 0, H)
    g.add_color_stop_rgba(0, *hexc("#2A1840"))
    g.add_color_stop_rgba(1, *hexc("#09060F"))
    cr.set_source(g)
    cr.rectangle(0, horizon, W, H - horizon)
    cr.fill()
    rnd = random.Random(5)
    for i in range(60):
        t = i / 60
        y = horizon + (H - horizon) * (t ** 1.6) + 4
        w = sr * (1.6 - t) * (0.5 + rnd.random())
        cr.rectangle(sx - w / 2 + (rnd.random() - 0.5) * sr * 0.5, y, w, H * 0.003 * (1 + t * 2))
        cr.set_source_rgba(1, 0.65, 0.45, 0.42 * (1 - t))
        cr.fill()
    # hòn đảo nhỏ của chú mèo (bên trái, gần nhất)
    ix, iw, ih = W * 0.2, W * 0.16, H * 0.055
    cr.move_to(ix - iw / 2, horizon + 2)
    cr.curve_to(ix - iw * 0.25, horizon - ih, ix + iw * 0.25, horizon - ih, ix + iw / 2, horizon + 2)
    cr.close_path()
    cr.set_source_rgba(*hexc("#1A0F2B"))
    cr.fill()
    # chú mèo ngồi trên đảo (bóng tối, mắt phản chiếu nắng)
    cat(cr, ix, horizon - ih * 0.72 - H * 0.085 * 0.30, H * 0.085, body="#1A0F2B", inner="#1A0F2B", visor="#1A0F2B", eye="#FFB38A", shade=False)
    vignette(cr, 0.35)


def aurora(cr):
    """Cực quang trên bầu trời sao."""
    vgrad(cr, [(0, "#03040C"), (0.7, "#060A18"), (1, "#0A0816")])
    rnd = random.Random(11)
    for _ in range(int(1400 * S * S + 200)):
        x, y = rnd.random() * W, rnd.random() * H * 0.9
        r = (0.4 + rnd.random() ** 3 * 1.8) * max(1, H / 1080)
        cr.set_source_rgba(1, 1, 1, 0.15 + rnd.random() * 0.6)
        cr.arc(x, y, r, 0, 2 * math.pi)
        cr.fill()
    # rèm cực quang: nhiều vệt dọc mảnh dọc theo một đường cong
    glow(cr, W * 0.35, H * 0.38, H * 0.55, "#22D3EE", 0.16)
    glow(cr, W * 0.7, H * 0.30, H * 0.5, "#A855F7", 0.14)
    curtains = [("#22D3EE", "#4ADE80", 0.38, 0.0, 1.0), ("#A855F7", "#22D3EE", 0.30, 1.7, 0.8), ("#4ADE80", "#14B8A6", 0.22, 3.1, 0.6)]
    for c_top, c_bot, base, ph, k in curtains:
        n = int(900 * S + 120)
        for i in range(n):
            t = i / n
            x = -0.05 * W + 1.1 * W * t
            y = H * (base + 0.10 * math.sin(ph + t * 5.2) + 0.04 * math.sin(ph * 2 + t * 13))
            h = H * (0.18 + 0.20 * (0.5 + 0.5 * math.sin(ph + t * 9.0))) * k
            a = 0.10 * (0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 31 + ph))) * (0.5 + 0.5 * math.sin(math.pi * t))
            g = cairo.LinearGradient(0, y - h, 0, y + h * 0.15)
            g.add_color_stop_rgba(0, *hexc(c_top, 0))
            g.add_color_stop_rgba(0.6, *hexc(c_top, a))
            g.add_color_stop_rgba(0.92, *hexc(c_bot, a * 1.6))
            g.add_color_stop_rgba(1, *hexc(c_bot, 0))
            cr.set_source(g)
            cr.rectangle(x, y - h, 1.1 * W / n * 4.0, h * 1.15)
            cr.fill()
    glow(cr, W * 0.5, H * 1.05, H * 0.9, "#14B8A6", 0.18)
    # đường chân trời: dãy núi tối
    cr.move_to(0, H)
    rnd = random.Random(2)
    x = 0
    cr.line_to(0, H * 0.86)
    while x < W:
        x += W * (0.02 + rnd.random() * 0.05)
        cr.line_to(x, H * (0.80 + rnd.random() * 0.08))
    cr.line_to(W, H)
    cr.close_path()
    cr.set_source_rgba(*hexc("#04050B"))
    cr.fill()
    vignette(cr, 0.4)


def prism(cr):
    """Những ô bo tròn kiểu icon Islet bằng kính, xếp chồng, nghiêng."""
    vgrad(cr, [(0, "#0B0B16"), (1, "#05050B")])
    glow(cr, W * 0.65, H * 0.45, H * 0.85, "#8B7CFF", 0.35)
    glow(cr, W * 0.3, H * 0.7, H * 0.6, "#FF6B97", 0.20)
    rnd = random.Random(21)
    cols = ["#8B7CFF", "#5B8CFF", "#FF6B97", "#2EC4B6", "#FF9F43", "#A855F7"]

    def squircle(cr, s):
        r = s * 0.27
        h = s / 2
        cr.new_sub_path()
        cr.arc(h - r, -h + r, r, -math.pi / 2, 0)
        cr.arc(h - r, h - r, r, 0, math.pi / 2)
        cr.arc(-h + r, h - r, r, math.pi / 2, math.pi)
        cr.arc(-h + r, -h + r, r, math.pi, 3 * math.pi / 2)
        cr.close_path()

    tiles = []
    for i in range(16):
        tiles.append((W * (0.38 + rnd.random() * 0.55), H * (0.1 + rnd.random() * 0.8), H * (0.10 + rnd.random() ** 2 * 0.32),
                      (rnd.random() - 0.5) * 0.9, cols[i % len(cols)], 0.10 + rnd.random() * 0.22))
    tiles.sort(key=lambda t: -t[2])
    for x, y, s, rot, col, a in tiles:
        cr.save()
        cr.translate(x, y)
        cr.rotate(rot)
        squircle(cr, s)
        g = cairo.LinearGradient(-s / 2, -s / 2, s / 2, s / 2)
        g.add_color_stop_rgba(0, *mix(hexc(col, a * 1.6), (1, 1, 1, a * 1.6), 0.25))
        g.add_color_stop_rgba(1, *hexc(col, a * 0.35))
        cr.set_source(g)
        cr.fill_preserve()
        g = cairo.LinearGradient(-s / 2, -s / 2, s / 2, s / 2)
        g.add_color_stop_rgba(0, 1, 1, 1, 0.45)
        g.add_color_stop_rgba(0.5, 1, 1, 1, 0.05)
        g.add_color_stop_rgba(1, 1, 1, 1, 0.18)
        cr.set_source(g)
        cr.set_line_width(max(1.2, H * 0.0013))
        cr.stroke()
        cr.restore()
    vignette(cr, 0.45)


def midnight(cr):
    """Tối giản, gần đen (hợp màn OLED): quỹ đạo mảnh quanh dấu mèo nhỏ."""
    vgrad(cr, [(0, "#06060B"), (1, "#020205")])
    cx, cy = W * 0.5, H * 0.5
    glow(cr, cx, cy, H * 0.5, "#8B7CFF", 0.16)
    for i, (rx, ry, rot, a) in enumerate([(0.30, 0.10, -0.25, 0.30), (0.42, 0.15, -0.25, 0.20), (0.56, 0.21, -0.25, 0.12), (0.72, 0.28, -0.25, 0.07)]):
        cr.save()
        cr.translate(cx, cy)
        cr.rotate(rot)
        cr.scale(1, ry / rx)
        cr.arc(0, 0, H * rx, 0, 2 * math.pi)
        cr.restore()
        cr.set_source_rgba(0.62, 0.56, 1, a)
        cr.set_line_width(max(1, H * 0.0014))
        cr.stroke()
        # hành tinh nhỏ trên quỹ đạo
        t = 0.8 + i * 1.7
        px = cx + H * rx * math.cos(t) * math.cos(rot) - H * ry * math.sin(t) * math.sin(rot)
        py = cy + H * rx * math.cos(t) * math.sin(rot) + H * ry * math.sin(t) * math.cos(rot)
        col = ["#FF6B97", "#2EC4B6", "#FFB547", "#5B8CFF"][i]
        glow(cr, px, py, H * 0.03, col, 0.7)
        cr.set_source_rgba(*hexc(col))
        cr.arc(px, py, H * 0.006, 0, 2 * math.pi)
        cr.fill()
    cat(cr, cx, cy + H * 0.01, H * 0.11)
    vignette(cr, 0.3)


WALLS = {"islet": islet, "lagoon": lagoon, "dusk": dusk, "aurora": aurora, "prism": prism, "midnight": midnight}
# tên hiện trong Cài đặt (đọc từ theme/wallpapers/names.txt nếu cần)
NAMES = {"islet": "Islet", "lagoon": "Lagoon", "dusk": "Dusk Isles", "aurora": "Aurora", "prism": "Prism", "midnight": "Midnight"}


def render(name):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    cr = cairo.Context(surf)
    cr.set_antialias(cairo.ANTIALIAS_BEST)
    WALLS[name](cr)
    grain(cr)
    os.makedirs(OUT, exist_ok=True)
    png = os.path.join(OUT, f".{name}.png")
    surf.write_to_png(png)
    pb = GdkPixbuf.Pixbuf.new_from_file(png)
    pb.savev(os.path.join(OUT, f"{name}.jpg"), "jpeg", ["quality"], ["92"])
    os.remove(png)
    print("wrote", os.path.join(OUT, f"{name}.jpg"))


if __name__ == "__main__":
    for n in (sys.argv[1:] or WALLS):
        render(n)
