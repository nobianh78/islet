#!/usr/bin/env python3
"""Vẽ bộ con trỏ chuột "Islet-Cursors" → theme/cursors/Islet-Cursors (định dạng Xcursor).

    python3 scripts/make-cursors.py
    python3 scripts/make-cursors.py --preview out/cursors.png    # thêm ảnh xem trước

Phong cách: thân tối (#15151F → #0E0E16) viền trắng, bóng mềm; chi tiết nhấn màu tím Islet (#8B7CFF).
Mỗi hình vẽ trong ô 32×32 đơn vị rồi phóng theo từng cỡ (24 … 96 px) nên nét nào cũng sắc.
Kỹ thuật viền: vẽ các mảnh bằng nét trắng dày trước, rồi tô thân tối lên trên → viền bao quanh
cả khối hợp (bàn tay = lòng bàn tay + các ngón) mà không cần tính hợp hình.
Chỉ cần pycairo.
"""
import math, os, struct, sys
import cairo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME = "Islet-Cursors"
OUT = os.path.join(ROOT, "theme", "cursors", THEME)
SIZES = [24, 32, 40, 48, 64, 96]

DARK_TOP = (0.105, 0.098, 0.165)     # #1B1930
DARK_BOT = (0.055, 0.055, 0.086)     # #0E0E16
WHITE = (1, 1, 1)
VIOLET = (0.545, 0.486, 1.0)         # #8B7CFF
RED = (1.0, 0.373, 0.341)            # #FF5F57
GREEN = (0.204, 0.780, 0.482)        # #34C77B
OUTLINE = 1.7                        # độ dày viền trắng (đơn vị ô 32)


def rrect(cr, x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def dark_fill(cr, y0=0, y1=32):
    g = cairo.LinearGradient(0, y0, 0, y1)
    g.add_color_stop_rgb(0, *DARK_TOP)
    g.add_color_stop_rgb(1, *DARK_BOT)
    cr.set_source(g)


def body(cr, shapes, shadow=True, fill=None):
    """shapes: các hàm vẽ path. Bóng → viền trắng (nét dày) → thân tối."""
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    if shadow:
        for i, a in enumerate((0.10, 0.08, 0.06, 0.04)):
            cr.save()
            cr.translate(0.25, 0.9 + i * 0.35)
            for s in shapes:
                s(cr)
                cr.set_source_rgba(0, 0, 0, a)
                cr.set_line_width(OUTLINE * 2 + 1.2 + i * 1.1)
                cr.stroke_preserve()
                cr.fill()
            cr.restore()
    for s in shapes:
        s(cr)
        cr.set_source_rgb(*WHITE)
        cr.set_line_width(OUTLINE * 2)
        cr.stroke_preserve()
        cr.fill()
    for s in shapes:
        s(cr)
        if fill:
            cr.set_source_rgb(*fill)
        else:
            dark_fill(cr)
        cr.fill()


def lines(cr, segs, width=1.6, color=None, outline=True):
    """Đường kẻ có viền trắng (I-beam, chữ thập…)."""
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    for pass_ in ("shadow", "outline", "fill"):
        if pass_ == "shadow":
            cr.save(); cr.translate(0.2, 0.8)
        for seg in segs:
            cr.move_to(*seg[0])
            for p in seg[1:]:
                cr.line_to(*p)
        if pass_ == "shadow":
            cr.set_source_rgba(0, 0, 0, 0.22); cr.set_line_width(width + OUTLINE * 2 + 0.8); cr.stroke(); cr.restore()
        elif pass_ == "outline":
            if outline:
                cr.set_source_rgb(*WHITE); cr.set_line_width(width + OUTLINE * 2); cr.stroke()
            else:
                cr.new_path()
        else:
            if color:
                cr.set_source_rgb(*color)
            else:
                dark_fill(cr)
            cr.set_line_width(width); cr.stroke()


# ---------------------------------------------------------------- hình

def arrow_path(cr, k=1.0, ox=0, oy=0):
    pts = [(3, 2.5), (3, 23.5), (8.2, 18.6), (11.6, 26.4), (15.2, 24.9), (11.9, 17.3), (18.9, 17.3)]
    cr.move_to(ox + pts[0][0] * k, oy + pts[0][1] * k)
    for x, y in pts[1:]:
        cr.line_to(ox + x * k, oy + y * k)
    cr.close_path()


def arrow(cr):
    body(cr, [arrow_path])
    # vệt tím nhỏ dọc cạnh trái: dấu ấn Islet
    cr.set_source_rgba(*VIOLET, 0.95)
    cr.set_line_width(1.3)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    cr.move_to(4.6, 6.4)
    cr.line_to(4.6, 15.5)
    cr.stroke()


def small_arrow(cr):
    """Mũi tên thu nhỏ ở góc trên-trái, để gắn huy hiệu (copy, help…)."""
    body(cr, [lambda c: arrow_path(c, 0.78, 0.6, 0.4)])


def badge(cr, cx, cy, r, color, glyph):
    cr.arc(cx, cy + 0.6, r + OUTLINE + 0.4, 0, 2 * math.pi)
    cr.set_source_rgba(0, 0, 0, 0.22); cr.fill()
    cr.arc(cx, cy, r + OUTLINE, 0, 2 * math.pi)
    cr.set_source_rgb(*WHITE); cr.fill()
    cr.arc(cx, cy, r, 0, 2 * math.pi)
    cr.set_source_rgb(*color); cr.fill()
    cr.set_source_rgb(*WHITE)
    cr.set_line_width(1.5)
    cr.set_line_cap(cairo.LINE_CAP_ROUND)
    glyph(cr, cx, cy, r)


def g_plus(cr, cx, cy, r):
    d = r * 0.55
    cr.move_to(cx - d, cy); cr.line_to(cx + d, cy); cr.move_to(cx, cy - d); cr.line_to(cx, cy + d); cr.stroke()


def g_minus(cr, cx, cy, r):
    d = r * 0.55
    cr.move_to(cx - d, cy); cr.line_to(cx + d, cy); cr.stroke()


def g_question(cr, cx, cy, r):
    cr.set_line_width(1.4)
    cr.arc(cx, cy - r * 0.25, r * 0.38, math.pi * 1.05, math.pi * 2.35)
    cr.line_to(cx, cy + r * 0.2)
    cr.stroke()
    cr.arc(cx, cy + r * 0.55, 0.75, 0, 2 * math.pi); cr.fill()


def g_link(cr, cx, cy, r):
    d = r * 0.45
    cr.move_to(cx - d, cy + d); cr.line_to(cx + d, cy - d); cr.stroke()
    cr.move_to(cx - d * 0.2, cy - d); cr.line_to(cx + d, cy - d); cr.line_to(cx + d, cy + d * 0.2); cr.stroke()


def g_menu(cr, cx, cy, r):
    d = r * 0.5
    for dy in (-d * 0.8, 0, d * 0.8):
        cr.move_to(cx - d, cy + dy); cr.line_to(cx + d, cy + dy)
    cr.set_line_width(1.2); cr.stroke()


def g_block(cr, cx, cy, r):
    d = r * 0.5
    cr.move_to(cx - d, cy + d); cr.line_to(cx + d, cy - d); cr.stroke()


def with_badge(color, glyph):
    def draw(cr):
        small_arrow(cr)
        badge(cr, 21.5, 21.5, 5.2, color, glyph)
    return draw


def spinner(cr, cx, cy, r, phase, width=2.6):
    # vòng nền tối viền trắng + cung tím quay
    cr.arc(cx, cy + 0.7, r + width / 2 + OUTLINE + 0.4, 0, 2 * math.pi)
    cr.set_source_rgba(0, 0, 0, 0.2); cr.fill()
    cr.arc(cx, cy, r + width / 2 + OUTLINE, 0, 2 * math.pi)
    cr.set_source_rgb(*WHITE); cr.fill()
    cr.arc(cx, cy, r + width / 2, 0, 2 * math.pi)
    dark_fill(cr, cy - r, cy + r); cr.fill()
    cr.arc(cx, cy, max(0.1, r - width / 2), 0, 2 * math.pi)
    cr.set_source_rgb(*WHITE); cr.fill()
    cr.arc(cx, cy, max(0.1, r - width / 2 - 0.01), 0, 2 * math.pi)
    cr.set_operator(cairo.OPERATOR_CLEAR); cr.fill(); cr.set_operator(cairo.OPERATOR_OVER)
    # cung tím mờ dần ở đuôi
    a0 = phase * 2 * math.pi - math.pi / 2
    n = 14
    for i in range(n):
        t = i / n
        cr.arc(cx, cy, r, a0 + t * math.pi * 1.25, a0 + (t + 1 / n) * math.pi * 1.25 + 0.02)
        cr.set_source_rgba(*VIOLET, 0.15 + 0.85 * t)
        cr.set_line_width(width * 0.85)
        cr.set_line_cap(cairo.LINE_CAP_BUTT)
        cr.stroke()


FRAMES = 12


def wait_frames():
    return [lambda cr, f=f: spinner(cr, 16, 16, 9.5, f / FRAMES, 3.4) for f in range(FRAMES)]


def progress_frames():
    def make(f):
        def draw(cr):
            small_arrow(cr)
            spinner(cr, 22, 22, 5.2, f / FRAMES, 2.4)
        return draw
    return [make(f) for f in range(FRAMES)]


def ibeam(cr):
    lines(cr, [[(12.5, 6), (14.5, 6.2), (16, 7.6), (17.5, 6.2), (19.5, 6)], [(16, 7.6), (16, 24.4)],
               [(12.5, 26), (14.5, 25.8), (16, 24.4), (17.5, 25.8), (19.5, 26)]], 1.5)


def vtext(cr):
    cr.save(); cr.translate(16, 16); cr.rotate(math.pi / 2); cr.translate(-16, -16); ibeam(cr); cr.restore()


def crosshair(cr):
    lines(cr, [[(16, 5), (16, 13)], [(16, 19), (16, 27)], [(5, 16), (13, 16)], [(19, 16), (27, 16)]], 1.5)
    cr.arc(16, 16, 1.4, 0, 2 * math.pi); cr.set_source_rgb(*VIOLET); cr.fill()


def cell(cr):
    def plus(c):
        rrect(c, 13.2, 5, 5.6, 22, 1.2)
        rrect(c, 5, 13.2, 22, 5.6, 1.2)
    body(cr, [plus])


def double_arrow_path(length=22, head=6.5, shaft=2.4, headw=7.5):
    def p(cr):
        L = length / 2
        cr.move_to(-L, 0)
        cr.line_to(-L + head, -headw / 2)
        cr.line_to(-L + head, -shaft / 2)
        cr.line_to(L - head, -shaft / 2)
        cr.line_to(L - head, -headw / 2)
        cr.line_to(L, 0)
        cr.line_to(L - head, headw / 2)
        cr.line_to(L - head, shaft / 2)
        cr.line_to(-L + head, shaft / 2)
        cr.line_to(-L + head, headw / 2)
        cr.close_path()
    return p


def resize(angle, bar=False):
    def draw(cr):
        cr.save()
        cr.translate(16, 16)
        cr.rotate(angle)
        shapes = [double_arrow_path(24 if not bar else 26)]
        if bar:
            shapes.append(lambda c: rrect(c, -1.4, -8, 2.8, 16, 1))
        body(cr, shapes)
        cr.restore()
    return draw


def fleur(cr):
    cr.save()
    cr.translate(16, 16)
    body(cr, [double_arrow_path(26, 5.5, 2.4, 7), lambda c: (c.save(), c.rotate(math.pi / 2), double_arrow_path(26, 5.5, 2.4, 7)(c), c.restore())])
    cr.arc(0, 0, 1.6, 0, 2 * math.pi); cr.set_source_rgb(*VIOLET); cr.fill()
    cr.restore()


def hand_shapes(kind):
    """Bàn tay: point (ngón trỏ), open (xoè), closed (nắm)."""
    shapes = [lambda c: rrect(c, 8.2, 14.2, 16.2, 13.6, 5.2)]                  # lòng bàn tay
    if kind == "point":
        shapes += [lambda c: rrect(c, 10.2, 2.6, 4.4, 17, 2.2),                 # ngón trỏ
                   lambda c: rrect(c, 14.4, 11.4, 3.9, 8.5, 1.95),
                   lambda c: rrect(c, 18.1, 12.4, 3.7, 8, 1.85),
                   lambda c: rrect(c, 21.5, 13.8, 3.3, 7, 1.65)]
    elif kind == "open":
        shapes += [lambda c: rrect(c, 9.6, 5.2, 3.9, 13, 1.95),
                   lambda c: rrect(c, 13.6, 3.4, 3.9, 14, 1.95),
                   lambda c: rrect(c, 17.6, 4.4, 3.8, 13, 1.9),
                   lambda c: rrect(c, 21.4, 7.2, 3.4, 11, 1.7)]
    else:
        shapes += [lambda c: rrect(c, 9.6, 11.2, 3.9, 7, 1.95),
                   lambda c: rrect(c, 13.6, 10.4, 3.9, 7.5, 1.95),
                   lambda c: rrect(c, 17.6, 10.8, 3.8, 7, 1.9),
                   lambda c: rrect(c, 21.4, 12.2, 3.4, 6, 1.7)]
    # ngón cái (xiên)
    def thumb(c):
        c.save(); c.translate(8.6, 19.4); c.rotate(-0.75 if kind != "closed" else -0.35)
        rrect(c, -2.0, -6.5, 4.0, 9.5, 2.0); c.restore()
    shapes.append(thumb)
    return shapes


def hand(kind):
    def draw(cr):
        body(cr, hand_shapes(kind))
        if kind == "point":       # móng tím ở đầu ngón trỏ
            cr.arc(12.4, 5.6, 1.15, 0, 2 * math.pi); cr.set_source_rgb(*VIOLET); cr.fill()
    return draw


def not_allowed(cr):
    cr.arc(16, 16.7, 10.6 + OUTLINE, 0, 2 * math.pi); cr.set_source_rgba(0, 0, 0, 0.22); cr.fill()
    cr.arc(16, 16, 10 + OUTLINE, 0, 2 * math.pi); cr.set_source_rgb(*WHITE); cr.fill()
    cr.arc(16, 16, 10, 0, 2 * math.pi); cr.set_source_rgb(*RED); cr.fill()
    cr.arc(16, 16, 6.6, 0, 2 * math.pi); cr.set_source_rgb(*WHITE); cr.fill()
    cr.arc(16, 16, 5.0, 0, 2 * math.pi)
    cr.set_operator(cairo.OPERATOR_CLEAR); cr.fill(); cr.set_operator(cairo.OPERATOR_OVER)
    cr.arc(16, 16, 6.6, 0, 2 * math.pi); cr.set_source_rgb(*RED)
    cr.set_line_width(0.01); cr.new_path()
    cr.save(); cr.translate(16, 16); cr.rotate(-math.pi / 4)
    rrect(cr, -7.6, -1.6, 15.2, 3.2, 0.8); cr.set_source_rgb(*RED); cr.fill()
    cr.restore()
    # vòng đỏ trong (sau khi đục lỗ)
    cr.arc(16, 16, 5.8, 0, 2 * math.pi); cr.set_source_rgb(*RED); cr.set_line_width(1.6); cr.stroke()


def magnifier(sign):
    def draw(cr):
        lines(cr, [[(20.5, 20.5), (27, 27)]], 3.2)
        cr.arc(14, 14, 8.4 + OUTLINE, 0, 2 * math.pi); cr.set_source_rgb(*WHITE); cr.fill()
        cr.arc(14, 14, 8.4, 0, 2 * math.pi); dark_fill(cr, 5, 23); cr.fill()
        cr.set_source_rgb(*VIOLET); cr.set_line_width(1.8); cr.set_line_cap(cairo.LINE_CAP_ROUND)
        cr.move_to(10.5, 14); cr.line_to(17.5, 14)
        if sign == "+":
            cr.move_to(14, 10.5); cr.line_to(14, 17.5)
        cr.stroke()
    return draw


def pencil(cr):
    cr.save(); cr.translate(16, 16); cr.rotate(math.pi / 4)
    def p(c):
        c.move_to(-2.6, -12); c.line_to(2.6, -12); c.line_to(2.6, 7); c.line_to(0, 12); c.line_to(-2.6, 7); c.close_path()
    body(cr, [p])
    cr.move_to(-2.6, 7); cr.line_to(0, 12); cr.line_to(2.6, 7); cr.close_path(); cr.set_source_rgb(*VIOLET); cr.fill()
    cr.restore()


# tên chính → (hàm vẽ hoặc danh sách khung hình, điểm nóng (đơn vị 32), bí danh)
CURSORS = {
    "default": (arrow, (3, 2.5), ["left_ptr", "arrow", "top_left_arrow", "left-arrow", "x-cursor", "X_cursor", "right_ptr", "draft_large", "draft_small"]),
    "pointer": (hand("point"), (12.4, 3.2), ["hand", "hand1", "hand2", "pointing_hand", "e29285e634086352946a0e7090d73106", "9d800788f1b08800ae810202380a0822"]),
    "text": (ibeam, (16, 16), ["xterm", "ibeam"]),
    "vertical-text": (vtext, (16, 16), []),
    "wait": (wait_frames(), (16, 16), ["watch", "0426c94ea35c87780ff01dc239897213"]),
    "progress": (progress_frames(), (2.5, 2.4), ["left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f", "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"]),
    "help": (with_badge(VIOLET, g_question), (2.5, 2.4), ["question_arrow", "whats_this", "left_ptr_help", "5c6cd98b3f3ebcb1f9c7f1c204630408", "d9ce0ab605698f320427677b458ad60b"]),
    "context-menu": (with_badge(VIOLET, g_menu), (2.5, 2.4), []),
    "copy": (with_badge(GREEN, g_plus), (2.5, 2.4), ["dnd-copy", "1081e37283d90000800003c07f3ef6bf", "6407b0e94181790501fd1e167b474872", "b66166c04f8c3109214a4fbd64a50fc8"]),
    "alias": (with_badge(VIOLET, g_link), (2.5, 2.4), ["dnd-link", "link", "3085a0e285430894940527032f8b26df", "640fb0e74195791501fd1ed57b41487f", "a2a266d0498c3104214a47bd64ab0fc8"]),
    "no-drop": (with_badge(RED, g_block), (2.5, 2.4), ["dnd-no-drop"]),
    "not-allowed": (not_allowed, (16, 16), ["crossed_circle", "forbidden", "circle", "03b6e0fcb3499374a867c041f52298f0"]),
    "crosshair": (crosshair, (16, 16), ["cross", "tcross", "cross_reverse", "diamond_cross"]),
    "cell": (cell, (16, 16), ["plus"]),
    "move": (fleur, (16, 16), ["fleur", "all-scroll", "size_all", "dnd-move", "4498f0e0c1937ffe01fd06f973665830", "9081237383d90e509aa00f00170e968f"]),
    "grab": (hand("open"), (16, 14), ["openhand", "hand-open", "5aca4d189052212118709018842178c0"]),
    "grabbing": (hand("closed"), (16, 16), ["closedhand", "dnd-none", "208530c400c041818281048008011002"]),
    "ew-resize": (resize(0), (16, 16), ["e-resize", "w-resize", "size_hor", "h_double_arrow", "sb_h_double_arrow", "left_side", "right_side", "028006030e0e7ebffc7f7070c0600140", "14fef782d02440884392942c11205230"]),
    "ns-resize": (resize(math.pi / 2), (16, 16), ["n-resize", "s-resize", "size_ver", "v_double_arrow", "sb_v_double_arrow", "top_side", "bottom_side", "00008160000006810000408080010102", "2870a09082c103050810ffdffffe0204"]),
    "nwse-resize": (resize(math.pi / 4), (16, 16), ["nw-resize", "se-resize", "size_fdiag", "bd_double_arrow", "top_left_corner", "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000"]),
    "nesw-resize": (resize(-math.pi / 4), (16, 16), ["ne-resize", "sw-resize", "size_bdiag", "fd_double_arrow", "top_right_corner", "bottom_left_corner", "fcf1c3c7cd4491d801f1e1c78f100000"]),
    "col-resize": (resize(0, True), (16, 16), ["split_h"]),
    "row-resize": (resize(math.pi / 2, True), (16, 16), ["split_v"]),
    "zoom-in": (magnifier("+"), (14, 14), []),
    "zoom-out": (magnifier("-"), (14, 14), []),
    "pencil": (pencil, (7.5, 24.5), ["draft"]),
}


def render(draw, size):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    cr = cairo.Context(surf)
    cr.scale(size / 32.0, size / 32.0)
    cr.set_antialias(cairo.ANTIALIAS_BEST)
    draw(cr)
    surf.flush()
    return surf


def xcursor(frames_by_size, hot, delay=50):
    """Ghi file Xcursor: mỗi cỡ × mỗi khung hình là một ảnh ARGB (premultiplied)."""
    images = []
    for size, frames in frames_by_size:
        for surf in frames:
            w = h = size
            stride = surf.get_stride()
            data = bytes(surf.get_data())
            px = b"".join(data[y * stride:y * stride + w * 4] for y in range(h))   # BGRA (little-endian ARGB)
            xh = min(w - 1, int(round(hot[0] * size / 32)))
            yh = min(h - 1, int(round(hot[1] * size / 32)))
            hdr = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, w, h, xh, yh, delay if len(frames) > 1 else 0)
            images.append((size, hdr + px))
    ntoc = len(images)
    out = struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc)
    pos = 16 + ntoc * 12
    toc = b""
    for size, chunk in images:
        toc += struct.pack("<III", 0xFFFD0002, size, pos)
        pos += len(chunk)
    return out + toc + b"".join(c for _, c in images)


def main():
    cdir = os.path.join(OUT, "cursors")
    os.makedirs(cdir, exist_ok=True)
    for f in os.listdir(cdir):
        os.remove(os.path.join(cdir, f))
    for name, (draw, hot, aliases) in CURSORS.items():
        frames = draw if isinstance(draw, list) else [draw]
        data = xcursor([(s, [render(fr, s) for fr in frames]) for s in SIZES], hot)
        with open(os.path.join(cdir, name), "wb") as fh:
            fh.write(data)
        for a in aliases:
            if a != name and not os.path.exists(os.path.join(cdir, a)):
                os.symlink(name, os.path.join(cdir, a))
    with open(os.path.join(OUT, "index.theme"), "w") as fh:
        # KHÔNG ghi Inherits=Adwaita: Hyprland nạp theme được kế thừa trước và lấy hình của nó thay cho hình Islet
        fh.write(f"[Icon Theme]\nName={THEME}\nComment=Islet cursors: dark with a white outline and a violet accent\n")
    with open(os.path.join(OUT, "cursor.theme"), "w") as fh:
        fh.write(f"[Icon Theme]\nName={THEME}\nInherits={THEME}\n")
    print(f"wrote {len(CURSORS)} cursors ({sum(len(a) for _, _, a in CURSORS.values())} aliases) → {OUT}")

    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        names = list(CURSORS)
        cols, cell_ = 7, 112
        rows = (len(names) + cols - 1) // cols
        sheet = cairo.ImageSurface(cairo.FORMAT_ARGB32, cols * cell_, rows * cell_)
        cr = cairo.Context(sheet)
        for i, n in enumerate(names):
            x, y = (i % cols) * cell_, (i // cols) * cell_
            cr.set_source_rgb(*([0.22, 0.2, 0.36] if (i // cols + i % cols) % 2 else [0.82, 0.82, 0.86]))
            cr.rectangle(x, y, cell_, cell_); cr.fill()
            d = CURSORS[n][0]
            s = render(d[3] if isinstance(d, list) else d, 64)
            cr.set_source_surface(s, x + 24, y + 14); cr.paint()
            cr.set_source_rgb(0, 0, 0) if (i // cols + i % cols) % 2 == 0 else cr.set_source_rgb(1, 1, 1)
            cr.select_font_face("Sans"); cr.set_font_size(11)
            cr.move_to(x + 6, y + cell_ - 8); cr.show_text(n)
        sheet.write_to_png(path)
        print("preview", path)


if __name__ == "__main__":
    main()
