#!/usr/bin/env python3
"""Bơm sự kiện chuột thật vào máy ảo qua QMP (để thử hover/animation).

    vm-mouse.py move X Y [X2 Y2 STEPS]   di chuột (toạ độ màn hình 1280x800)
    vm-mouse.py click X Y
    vm-mouse.py rclick X Y               chuột phải
"""
import json, os, socket, sys, time

SOCK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "qmp.sock")
W, H = 1280, 800

s = socket.socket(socket.AF_UNIX)
s.connect(SOCK)
f = s.makefile("rw")
f.readline()
def cmd(c, **a):
    f.write(json.dumps({"execute": c, "arguments": a} if a else {"execute": c}) + "\n"); f.flush()
    return f.readline()
cmd("qmp_capabilities")

def abs_ev(x, y):
    return [{"type": "abs", "data": {"axis": "x", "value": int(x * 32767 / W)}},
            {"type": "abs", "data": {"axis": "y", "value": int(y * 32767 / H)}}]

def move(x, y):
    cmd("input-send-event", events=abs_ev(x, y))

op = sys.argv[1]
a = [float(v) for v in sys.argv[2:]]
if op == "move":
    if len(a) >= 5:
        x1, y1, x2, y2, n = a[:5]
        for i in range(int(n) + 1):
            t = i / n
            move(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t); time.sleep(0.016)
    else:
        move(a[0], a[1])
elif op in ("click", "rclick"):
    btn = "right" if op == "rclick" else "left"
    move(a[0], a[1]); time.sleep(0.05)
    for down in (True, False):
        cmd("input-send-event", events=[{"type": "btn", "data": {"down": down, "button": btn}}]); time.sleep(0.06)
