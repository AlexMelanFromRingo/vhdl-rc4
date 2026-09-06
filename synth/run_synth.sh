#!/usr/bin/env bash
# =====================================================================
#  Синтез усіх ядер: GHDL (VHDL -> Verilog) -> Yosys.
#  Знімає три набори чисел:
#    * generic  - технологічно-незалежні вентилі + тригери
#    * ECP5     - LUT4 / FF для реальної FPGA (Lattice ECP5)
#    * CMOS     - оцінка кількості транзисторів (проксі для кремнію)
#  Використання: ./synth/run_synth.sh [ім'я_дизайна ...]
# =====================================================================
set -u
cd "$(dirname "$0")/.."

WORK=sim/work
OUT=synth/out
STD=--std=08
mkdir -p "$OUT"

# Стеля віртуальної пам'яті на один запуск Yosys (у КБ). Великий дизайн
# має впасти сам, а не спричинити OOM на всій машині.
YLIM=${YLIM:-10000000}
# SKIP_CMOS=1 пропускає найповільніший прохід (оцінка транзисторів).
SKIP_CMOS=${SKIP_CMOS:-0}

run_yosys() { ( ulimit -v "$YLIM"; yosys "$@" ); }

# ім'я:сутність:generic-и
DESIGNS=(
    "rc4:rc4_cipher:"
    "gost28147:gost_cipher:"
    "kuznyechik:kuznyechik_cipher:"
    "kalyna_128_128:kalyna_cipher:-gNB=2 -gNK=2"
    "kalyna_128_256:kalyna_cipher:-gNB=2 -gNK=4"
    "kalyna_256_256:kalyna_cipher:-gNB=4 -gNK=4"
    "kalyna_256_512:kalyna_cipher:-gNB=4 -gNK=8"
    "kalyna_512_512:kalyna_cipher:-gNB=8 -gNK=8"
    "strumok_256:strumok_cipher:-gKEY_WORDS=4"
    "strumok_512:strumok_cipher:-gKEY_WORDS=8"
)

[ -d "$WORK" ] || { echo "run ./sim/run_all.sh first (need analysed library)"; exit 1; }

sel=("${@:-}")
printf '%-16s %10s %10s %10s %10s %12s\n' design cells FFs LUT4 gates transistors
printf '%.0s-' {1..74}; echo

for d in "${DESIGNS[@]}"; do
    name=${d%%:*}; rest=${d#*:}; ent=${rest%%:*}; gen=${rest#*:}
    if [ -n "${sel[*]}" ] && [[ ! " ${sel[*]} " =~ " $name " ]]; then continue; fi

    ghdl synth $STD --workdir=$WORK $gen --out=verilog "$ent" > "$OUT/$name.v" 2>"$OUT/$name.ghdl.log" || {
        printf '%-16s %s\n' "$name" "GHDL FAILED"; continue; }

    # 1) технологічно-незалежний синтез
    run_yosys -q -l "$OUT/$name.generic.log" \
        -p "read_verilog -sv $OUT/$name.v; synth -top $ent; stat" >/dev/null 2>&1
    cells=$(python3 synth/parse_stat.py "$OUT/$name.generic.log" cells)
    ffs=$(python3 synth/parse_stat.py "$OUT/$name.generic.log" ff)

    # 2) відображення на ECP5
    run_yosys -q -l "$OUT/$name.ecp5.log" \
        -p "read_verilog -sv $OUT/$name.v; synth_ecp5 -top $ent -json $OUT/$name.ecp5.json; stat" >/dev/null 2>&1
    lut=$(python3 synth/parse_stat.py "$OUT/$name.ecp5.log" lut4)

    # 3) оцінка для CMOS-кремнію
    if [ "$SKIP_CMOS" = "0" ]; then
        run_yosys -q -l "$OUT/$name.cmos.log" \
            -p "read_verilog -sv $OUT/$name.v; synth -top $ent; \
                abc -g AND,NAND,OR,NOR,XOR,XNOR,ANDNOT,ORNOT,MUX,AOI3,OAI3,AOI4,OAI4; \
                stat -tech cmos" >/dev/null 2>&1
        gates=$(python3 synth/parse_stat.py "$OUT/$name.cmos.log" cells)
        trans=$(python3 synth/parse_stat.py "$OUT/$name.cmos.log" transistors)
    else
        gates="-"; trans="-"
    fi

    printf '%-16s %10s %10s %10s %10s %12s\n' \
        "$name" "${cells:-?}" "${ffs:-?}" "${lut:-?}" "${gates:-?}" "${trans:-?}"
done
