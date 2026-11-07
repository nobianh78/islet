#!/usr/bin/env python3
"""Tạo bộ âm thanh hệ thống của Islet (tổng hợp, không dùng mẫu thu sẵn) → theme/sounds/islet.

Một theme âm thanh chuẩn freedesktop ("islet"): tên file theo Sound Naming Spec, nên app GTK
(canberra) cũng dùng được khi đặt sound-theme = islet. Shell phát bằng pw-play.

Âm sắc chung: chuông thuỷ tinh mềm (vài hoạ âm hơi lệch, tắt dần), thêm chút vang cho ấm.
Chạy: python3 scripts/make-sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "theme", "sounds", "islet")


def note(name):
    """'C5' → Hz (A4 = 440)."""
    n = "C C# D D# E F F# G G# A A# B".split().index(name[:-1])
    return 440.0 * 2 ** ((n - 9) / 12 + int(name[-1]) - 4)


def silence(sec):
    return [0.0] * int(sec * RATE)


def mix(dst, src, at):
    i0 = int(at * RATE)
    if len(dst) < i0 + len(src):
        dst.extend([0.0] * (i0 + len(src) - len(dst)))
    for i, v in enumerate(src):
        dst[i0 + i] += v


def bell(freq, dur, amp=0.5, attack=0.004, decay=None, partials=((1, 1.0, 1.0), (2.0, 0.28, 1.8), (3.01, 0.10, 2.6), (4.18, 0.05, 3.4))):
    """Chuông mềm: (tỉ lệ tần số, biên độ, hệ số tắt nhanh hơn) cho mỗi hoạ âm."""
    decay = decay or dur / 4.5
    n = int(dur * RATE)
    out = [0.0] * n
    for ratio, a, k in partials:
        f = freq * ratio
        if f > RATE / 2.2:
            continue
        w = 2 * math.pi * f / RATE
        for i in range(n):
            t = i / RATE
            env = (t / attack if t < attack else 1.0) * math.exp(-t * k / decay)
            out[i] += a * env * math.sin(w * i)
    return [amp * v for v in out]


def noise(dur, amp=0.3, lp=0.15, attack=0.003, decay=0.06, seed=1):
    """Tiếng xào xạc / lách cách: nhiễu trắng qua lọc thông thấp một cực."""
    r = random.Random(seed)
    n = int(dur * RATE)
    out, y = [0.0] * n, 0.0
    for i in range(n):
        t = i / RATE
        y += lp * (r.uniform(-1, 1) - y)
        env = (t / attack if t < attack else 1.0) * math.exp(-t / decay)
        out[i] = amp * env * y
    return out


def highpass(x, a=0.97):
    out, prev_x, prev_y = [], 0.0, 0.0
    for v in x:
        y = a * (prev_y + v - prev_x)
        out.append(y)
        prev_x, prev_y = v, y
    return out


def reverb(x, wet=0.18, tail=0.6):
    """Vang nhỏ kiểu Schroeder (4 comb song song + 2 allpass), cho âm ấm hơn."""
    x = x + [0.0] * int(tail * RATE)
    combs = [(1557, 0.80), (1617, 0.79), (1491, 0.78), (1422, 0.77)]
    acc = [0.0] * len(x)
    for d, g in combs:
        d = int(d * RATE / 44100)
        buf = [0.0] * d
        j = 0
        for i, v in enumerate(x):
            y = buf[j]
            buf[j] = v + y * g
            acc[i] += y
            j = (j + 1) % d
    for d, g in ((225, 0.5), (556, 0.5)):
        d = int(d * RATE / 44100)
        buf = [0.0] * d
        j = 0
        for i, v in enumerate(acc):
            b = buf[j]
            y = -v + b
            buf[j] = v + b * g
            acc[i] = y
            j = (j + 1) % d
    return [v + wet * a / 4 for v, a in zip(x, acc)]


def write(name, mono, gain=1.0, width=0.0006):
    """Chuẩn hoá về -3 dBFS, làm mềm hai đầu, ghi WAV stereo (kênh phải trễ một chút cho rộng)."""
    peak = max(1e-9, max(abs(v) for v in mono))
    k = 0.707 * gain / peak
    fade = int(0.01 * RATE)
    n = len(mono)
    # cắt đuôi gần như im lặng
    while n > 1 and abs(mono[n - 1]) * k < 0.0005:
        n -= 1
    mono = mono[:n + fade]
    d = int(width * RATE)
    os.makedirs(os.path.join(OUT, "stereo"), exist_ok=True)
    path = os.path.join(OUT, "stereo", name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for i in range(len(mono)):
            fo = min(1.0, (len(mono) - i) / fade)
            l = mono[i] * k * fo
            r = (mono[i - d] if i >= d else 0.0) * k * fo
            frames += struct.pack("<hh", int(max(-1, min(1, l)) * 32767), int(max(-1, min(1, r)) * 32767))
        w.writeframes(bytes(frames))
    print(f"  {name}.wav  {len(mono) / RATE:.2f}s")


def seq(notes, step, dur, amp=0.5, **kw):
    out = []
    for i, nm in enumerate(notes):
        mix(out, bell(note(nm), dur, amp, **kw), i * step)
    return out


def main():
    print("Islet sounds →", os.path.relpath(OUT))
    # bật máy / đăng nhập: hợp âm Cmaj9 rải lên, có lớp nền êm
    s = []
    for i, nm in enumerate(["C4", "G4", "E5", "B5", "D6"]):
        mix(s, bell(note(nm), 2.4, 0.42 - i * 0.04, attack=0.02, decay=0.9), i * 0.09)
    pad = bell(note("C3"), 2.2, 0.25, attack=0.25, decay=1.2, partials=((1, 1, 1), (2, 0.4, 1.4), (3, 0.15, 2)))
    mix(s, pad, 0.0)
    write("desktop-login", reverb(s, wet=0.35, tail=1.0), gain=0.85)

    # thông báo: hai nốt thuỷ tinh đi lên
    write("message-new-instant", reverb(seq(["E6", "B6"], 0.085, 0.55, 0.5, decay=0.16), wet=0.22))
    # khoá: hai nốt đi xuống, trầm và ngắn · mở khoá: đi lên
    write("service-logout", reverb(seq(["G5", "C5"], 0.07, 0.4, 0.5, decay=0.12), wet=0.15))
    write("service-login", reverb(seq(["C5", "G5"], 0.07, 0.45, 0.5, decay=0.14), wet=0.18))
    # cắm sạc: nốt bật lên · rút sạc: rơi xuống
    write("power-plug", reverb(seq(["A5", "E6"], 0.06, 0.32, 0.5, decay=0.09), wet=0.12))
    write("power-unplug", reverb(seq(["E6", "A5"], 0.06, 0.32, 0.5, decay=0.09), wet=0.12))
    # xong việc (hẹn giờ, sao lưu, cập nhật): ba nốt rải lên
    write("complete", reverb(seq(["C6", "E6", "G6"], 0.08, 0.6, 0.45, decay=0.18), wet=0.25))
    # chuông hẹn giờ: lặp lại hai lần
    b = seq(["G6", "E6", "G6", "E6"], 0.16, 0.5, 0.45, decay=0.13)
    write("alarm-clock-elapsed", reverb(b, wet=0.2))
    # lỗi / cảnh báo: hai nốt trầm, mờ
    soft = ((1, 1.0, 1.0), (2.0, 0.18, 2.4))
    write("dialog-error", reverb(seq(["E4", "C4"], 0.11, 0.35, 0.55, decay=0.09, partials=soft), wet=0.12))
    write("dialog-warning", reverb(seq(["A4"], 0.0, 0.4, 0.55, decay=0.11, partials=soft), wet=0.12))
    # bỏ vào thùng rác: tiếng giấy sột soạt ngắn + "bịch" nhẹ
    t = []
    for i, (at, a) in enumerate([(0.0, 0.35), (0.035, 0.28), (0.07, 0.22), (0.11, 0.16)]):
        mix(t, highpass(noise(0.12, a, lp=0.35, decay=0.025, seed=10 + i)), at)
    mix(t, bell(note("A2"), 0.25, 0.55, attack=0.002, decay=0.05, partials=((1, 1, 1), (1.5, 0.3, 2))), 0.14)
    write("trash-move", reverb(t, wet=0.08, tail=0.2), gain=0.8)
    # đổ rác: vò giấy dài hơn
    t = []
    r = random.Random(7)
    at = 0.0
    for i in range(16):
        mix(t, highpass(noise(0.09, r.uniform(0.15, 0.4), lp=r.uniform(0.25, 0.5), decay=r.uniform(0.012, 0.03), seed=40 + i)), at)
        at += r.uniform(0.025, 0.06)
    write("trash-empty", reverb(t, wet=0.08, tail=0.2), gain=0.8)
    # chụp màn hình: màn trập hai nhịp
    sh = []
    mix(sh, highpass(noise(0.05, 0.6, lp=0.6, decay=0.008, seed=3), 0.9), 0.0)
    mix(sh, highpass(noise(0.06, 0.45, lp=0.45, decay=0.012, seed=4), 0.9), 0.075)
    write("screen-capture", reverb(sh, wet=0.06, tail=0.15), gain=0.75)
    # cắm / rút thiết bị (USB…)
    write("device-added", reverb(seq(["D6", "A6"], 0.05, 0.28, 0.45, decay=0.07), wet=0.1), gain=0.8)
    write("device-removed", reverb(seq(["A6", "D6"], 0.05, 0.28, 0.45, decay=0.07), wet=0.1), gain=0.8)
    # chỉnh âm lượng: một tiếng "tách" nhỏ
    write("audio-volume-change", bell(note("C6"), 0.09, 0.5, attack=0.001, decay=0.02, partials=((1, 1, 1), (2, 0.2, 2))), gain=0.6)
    write("bell", reverb(seq(["A5"], 0, 0.5, 0.5, decay=0.14), wet=0.2))

    with open(os.path.join(OUT, "index.theme"), "w") as f:
        f.write("[Sound Theme]\nName=Islet\nComment=Sounds of the Islet desktop\nInherits=freedesktop\nDirectories=stereo\n\n"
                "[stereo]\nOutputProfile=stereo\n")


if __name__ == "__main__":
    main()
