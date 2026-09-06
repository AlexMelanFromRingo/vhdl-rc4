#!/usr/bin/env python3
"""Витягує числа з ОСТАННЬОГО блоку статистики у лозі Yosys."""
import re, sys

def last_stat(path):
    try:
        txt = open(path, errors="replace").read()
    except OSError:
        return {}
    blocks = txt.split("Printing statistics.")
    if len(blocks) < 2:
        return {}
    b = blocks[-1]
    out = {}
    m = re.search(r"Number of cells:\s+(\d+)", b)
    if m: out["cells"] = int(m.group(1))
    m = re.search(r"Estimated number of transistors:\s+(\d+)", b)
    if m: out["transistors"] = int(m.group(1))
    # тригери: усі різновиди DFF/DLATCH, і generic, і ECP5 (TRELLIS_FF)
    ff = 0
    for name, n in re.findall(r"^\s+(\S+)\s+(\d+)\s*$", b, re.M):
        if re.search(r"DFF|DLATCH|TRELLIS_FF", name, re.I):
            ff += int(n)
    if ff: out["ff"] = ff
    m = re.search(r"^\s+LUT4\s+(\d+)\s*$", b, re.M)
    if m: out["lut4"] = int(m.group(1))
    return out

if __name__ == "__main__":
    print(last_stat(sys.argv[1]).get(sys.argv[2], "?"))
