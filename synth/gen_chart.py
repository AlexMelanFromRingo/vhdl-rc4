#!/usr/bin/env python3
"""
Малює порівняльну діаграму ресурсів із synth/out/summary.txt.
Чистий SVG без сторонніх бібліотек.
Запуск: python3 synth/gen_chart.py
"""
import pathlib, re, html

SRC  = pathlib.Path("synth/out/summary.txt")
DEST = pathlib.Path("docs/resources.svg")

PALETTE = {
    "rc4":        ("#8a8f98", "RC4"),
    "gost28147":  ("#c1666b", "GOST 28147-89"),
    "kuznyechik": ("#a4508b", "Kuznyechik"),
    "kalyna":     ("#2f7d43", "Kalyna"),
    "strumok":    ("#2b6cb0", "Strumok"),
}

def family(name):
    for k in PALETTE:
        if name.startswith(k):
            return k
    return "rc4"

def load():
    rows = []
    for ln in SRC.read_text().splitlines():
        p = ln.split()
        if len(p) == 6 and p[0] != "design" and p[1].isdigit():
            rows.append((p[0], int(p[1]), int(p[2]), int(p[3]), int(p[4]), int(p[5])))
    return rows

def bars(rows, idx, title, unit, x0, width):
    """Одна колонка діаграми: горизонтальні смуги з логарифмічним масштабом."""
    vals = [r[idx] for r in rows]
    top  = max(vals)
    out  = [f'<text x="{x0}" y="26" class="col">{html.escape(title)}</text>']
    for i, r in enumerate(rows):
        y = 46 + i * 30
        v = r[idx]
        w = max(2, int(width * (v / top) ** 0.5))     # sqrt: дрібні ядра видно
        c = PALETTE[family(r[0])][0]
        out.append(f'<rect x="{x0}" y="{y}" width="{w}" height="18" rx="3" fill="{c}" opacity="0.85"/>')
        out.append(f'<text x="{x0+w+7}" y="{y+13}" class="val">{v:,}</text>'.replace(",", " "))
    return "\n".join(out)

def main():
    rows = load()
    if not rows:
        print("no data in", SRC); return
    rowh, n = 30, len(rows)
    H = 46 + n * rowh + 56
    LBL, COL, GAP = 150, 210, 34
    cols = [(1, "Cells"), (2, "Flip-flops"), (3, "ECP5 LUT4"), (5, "Transistors (CMOS est.)")]
    W = LBL + len(cols) * (COL + GAP)

    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
         '<style>',
         'svg{background:#fbfbfd;font-family:"DejaVu Sans",system-ui,sans-serif}',
         '.name{font-size:12px;fill:#28313d}',
         '.val{font-size:10px;fill:#5a6a7d}',
         '.col{font-size:12px;font-weight:600;fill:#28313d}',
         '.note{font-size:10px;fill:#8a94a2}',
         '</style>',
         f'<rect width="{W}" height="{H}" fill="#fbfbfd"/>']

    for i, r in enumerate(rows):
        y = 46 + i * rowh
        p.append(f'<text x="10" y="{y+13}" class="name">{html.escape(r[0])}</text>')

    for j, (idx, title) in enumerate(cols):
        p.append(bars(rows, idx, title, "", LBL + j * (COL + GAP), COL - 60))

    p.append(f'<text x="10" y="{H-16}" class="note">'
             'Yosys 0.33 · bar length ∝ √value so small cores stay visible · '
             'ECP5 = Lattice LFE5U mapping · transistor count is Yosys&#39; CMOS estimate, not a real PDK</text>')
    p.append("</svg>")
    DEST.write_text("\n".join(p))
    print(f"{DEST}  ({DEST.stat().st_size} bytes, {n} designs)")

if __name__ == "__main__":
    main()
