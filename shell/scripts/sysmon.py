#!/usr/bin/env python3
"""Islet sysmon: mỗi giây in một dòng JSON về tình trạng máy (đọc thẳng /proc, /sys).

{ "cpu": %, "cores": [%...], "mem": {used,total,swapUsed,swapTotal} (byte),
  "net": {rx,tx} (byte/s), "disk": {used,total,read,write}, "temp": °C|null,
  "uptime": s, "procs": [[pid, ppid, name, cpu%, rss, user], ...] }
"""
import json
import os
import pwd
import shutil
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
NCPU = os.cpu_count() or 1


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def cpu_times():
    out = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        v = [int(x) for x in line.split()[1:]]
        idle = v[3] + (v[4] if len(v) > 4 else 0)
        out.append((sum(v), idle))
    return out


def mem():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, rest = line.partition(":")
        m[k] = int(rest.split()[0]) * 1024
    total = m.get("MemTotal", 0)
    avail = m.get("MemAvailable", 0)
    return {"used": total - avail, "total": total,
            "swapUsed": m.get("SwapTotal", 0) - m.get("SwapFree", 0), "swapTotal": m.get("SwapTotal", 0)}


def net_bytes():
    rx = tx = 0
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        name = name.strip()
        if name == "lo" or name.startswith(("veth", "docker", "br-", "virbr")):
            continue
        f = rest.split()
        rx += int(f[0])
        tx += int(f[8])
    return rx, tx


def disk_bytes():
    r = w = 0
    for line in read("/proc/diskstats").splitlines():
        f = line.split()
        name = f[2]
        # chỉ ổ vật lý, bỏ phân vùng
        if name.startswith(("loop", "ram", "zram", "dm-", "sr")):
            continue
        if name[-1].isdigit() and not name.startswith("nvme") and not name.startswith("mmcblk"):
            continue
        if (name.startswith("nvme") or name.startswith("mmcblk")) and "p" in name[4:]:
            continue
        r += int(f[5]) * 512
        w += int(f[9]) * 512
    return r, w


def temperature():
    best = None
    base = "/sys/class/thermal"
    try:
        zones = os.listdir(base)
    except OSError:
        zones = []
    for z in zones:
        if not z.startswith("thermal_zone"):
            continue
        t = read(f"{base}/{z}/temp").strip()
        kind = read(f"{base}/{z}/type").strip().lower()
        if t.lstrip("-").isdigit():
            c = int(t) / 1000
            if "pkg" in kind or "cpu" in kind or "x86" in kind or best is None:
                best = c
    if best is None:
        # hwmon (k10temp, coretemp)
        hw = "/sys/class/hwmon"
        try:
            for h in os.listdir(hw):
                name = read(f"{hw}/{h}/name").strip()
                if name in ("k10temp", "coretemp", "zenpower", "cpu_thermal"):
                    t = read(f"{hw}/{h}/temp1_input").strip()
                    if t.isdigit():
                        best = int(t) / 1000
                        break
        except OSError:
            pass
    return best


_users = {}


def user_of(uid):
    if uid not in _users:
        try:
            _users[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            _users[uid] = str(uid)
    return _users[uid]


def proc_snapshot():
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        stat = read(f"/proc/{pid}/stat")
        if not stat:
            continue
        try:
            l, r = stat.index("("), stat.rindex(")")
            name = stat[l + 1:r]
            f = stat[r + 2:].split()
            ppid = int(f[1])
            ticks = int(f[11]) + int(f[12])
            rss = int(f[21]) * PAGE
            uid = os.stat(f"/proc/{pid}").st_uid
        except (ValueError, IndexError, OSError):
            continue
        out[int(pid)] = (ppid, name, ticks, rss, uid)
    return out


def main():
    prev_cpu = cpu_times()
    prev_net = net_bytes()
    prev_disk = disk_bytes()
    prev_procs = proc_snapshot()
    prev_t = time.monotonic()
    while True:
        time.sleep(1)
        now = time.monotonic()
        dt = max(0.001, now - prev_t)

        cur = cpu_times()
        loads = []
        for (t1, i1), (t0, i0) in zip(cur, prev_cpu):
            dtot = t1 - t0
            loads.append(0.0 if dtot <= 0 else 100.0 * (1 - (i1 - i0) / dtot))
        prev_cpu = cur

        nb = net_bytes()
        net = {"rx": max(0, nb[0] - prev_net[0]) / dt, "tx": max(0, nb[1] - prev_net[1]) / dt}
        prev_net = nb

        db = disk_bytes()
        du = shutil.disk_usage("/")
        disk = {"used": du.used, "total": du.total,
                "read": max(0, db[0] - prev_disk[0]) / dt, "write": max(0, db[1] - prev_disk[1]) / dt}
        prev_disk = db

        procs = proc_snapshot()
        rows = []
        for pid, (ppid, name, ticks, rss, uid) in procs.items():
            p = prev_procs.get(pid)
            cpu = 0.0
            if p and ticks >= p[2]:
                cpu = (ticks - p[2]) / HZ / dt * 100.0 / NCPU
            rows.append([pid, ppid, name, round(cpu, 1), rss, user_of(uid)])
        prev_procs = procs
        prev_t = now

        up = float((read("/proc/uptime").split() or ["0"])[0])
        out = {
            "cpu": round(loads[0], 1) if loads else 0,
            "cores": [round(x, 1) for x in loads[1:]],
            "mem": mem(),
            "net": net,
            "disk": disk,
            "temp": temperature(),
            "uptime": up,
            "procs": rows,
        }
        sys.stdout.write(json.dumps(out, separators=(",", ":")) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
