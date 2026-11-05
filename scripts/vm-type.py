#!/usr/bin/env python3
"""Gõ phím vào máy ảo qua QMP (để thử ô nhập).  vm-type.py "chữ cần gõ"   (\\n = Enter)"""
import json, os, socket, sys, time
SOCK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "qmp.sock")
s = socket.socket(socket.AF_UNIX); s.connect(SOCK); f = s.makefile("rw"); f.readline()
def c(x): f.write(json.dumps(x) + "\n"); f.flush(); return f.readline()
c({"execute": "qmp_capabilities"})
names = {" ": "spc", "\n": "ret", ".": "dot", ",": "comma", "-": "minus", "/": "slash"}
def key(k, shift=False):
    keys = ([{"type": "qcode", "data": "shift"}] if shift else []) + [{"type": "qcode", "data": k}]
    c({"execute": "send-key", "arguments": {"keys": keys}}); time.sleep(0.03)
for ch in sys.argv[1].replace("\\n", "\n"):
    if ch == ":": key("semicolon", True)
    elif ch in names: key(names[ch])
    elif ch.isupper(): key(ch.lower(), True)
    else: key(ch)
