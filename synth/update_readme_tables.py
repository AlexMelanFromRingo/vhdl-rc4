#!/usr/bin/env python3
"""
Вставляє таблицю результатів синтезу в усі мовні версії README.
Числа беруться з synth/out/summary.txt, тож переклади не розходяться.
Запуск: python3 synth/update_readme_tables.py
"""
import pathlib, re

SRC = pathlib.Path("synth/out/summary.txt")

HEADERS = {
    "README.md":    ["Design", "Cells", "Flip-flops", "ECP5 LUT4", "Gates (CMOS)", "Transistors", "kGE"],
    "README.uk.md": ["Дизайн", "Комірок", "Тригерів", "ECP5 LUT4", "Вентилів (CMOS)", "Транзисторів", "kGE"],
    "README.ru.md": ["Дизайн", "Ячеек", "Триггеров", "ECP5 LUT4", "Вентилей (CMOS)", "Транзисторов", "kGE"],
}
PRETTY = {
    "rc4": "RC4", "gost28147": "GOST 28147-89", "kuznyechik": "Kuznyechik",
    "kalyna_128_128": "Kalyna-128/128", "kalyna_128_256": "Kalyna-128/256",
    "kalyna_256_256": "Kalyna-256/256", "kalyna_256_512": "Kalyna-256/512",
    "kalyna_512_512": "Kalyna-512/512",
    "strumok_256": "Strumok-256", "strumok_512": "Strumok-512",
}

def rows():
    out = []
    for ln in SRC.read_text().splitlines():
        p = ln.split()
        if len(p) == 6 and p[0] != "design" and p[1].isdigit():
            # kGE: площа в еквівалентах вентиля NAND2 (4 транзистори) - стандартна
            # ASIC-метрика, зручна для порівняння з опублікованими роботами.
            kge = int(p[5]) / 4 / 1000
            out.append([PRETTY.get(p[0], p[0])]
                       + [f"{int(v):,}".replace(",", " ") for v in p[1:]]
                       + [f"{kge:.1f}"])
    return out

def table(hdr, data):
    w = ["| " + " | ".join(hdr) + " |",
         "|" + "---|" * len(hdr)]
    for r in data:
        w.append("| " + " | ".join(r) + " |")
    return "\n".join(w)

def main():
    data = rows()
    if not data:
        print("no synthesis data yet"); return
    for f, hdr in HEADERS.items():
        p = pathlib.Path(f)
        if not p.exists():
            continue
        txt = p.read_text()
        new = "<!--SYNTH:BEGIN-->\n" + table(hdr, data) + "\n<!--SYNTH:END-->"
        txt2, n = re.subn(r"<!--SYNTH:BEGIN-->.*?<!--SYNTH:END-->", new, txt, flags=re.S)
        if n:
            p.write_text(txt2)
            print(f"  {f}: table updated ({len(data)} rows)")
        else:
            print(f"  {f}: no <!--SYNTH:BEGIN--> marker, skipped")

if __name__ == "__main__":
    main()
