#!/usr/bin/env bash
# =====================================================================
#  Прогін усіх тестбенчів проєкту через GHDL.
#  Використання:  ./sim/run_all.sh [ім'я_тестбенча ...]
#  Без аргументів проганяються всі.
# =====================================================================
set -u
cd "$(dirname "$0")/.."

WORK=${WORK:-sim/work}
STD=--std=08
mkdir -p "$WORK"

SOURCES=(
    common/crypto_util.vhd
    RC4_Inside_Project_Directory/rc4_package.vhd
    RC4_Inside_Project_Directory/rc4_cipher.vhd
    RC4_Inside_Project_Directory/rc4_tb.vhd
    GOST_28147_89/gost_package.vhd
    GOST_28147_89/gost_cipher.vhd
    GOST_28147_89/gost_tb.vhd
    Kuznyechik/kuznyechik_package.vhd
    Kuznyechik/kuznyechik_cipher.vhd
    Kuznyechik/kuznyechik_tb.vhd
    Kalyna/kalyna_package.vhd
    Kalyna/kalyna_cipher.vhd
    Kalyna/kalyna_tb.vhd
    Strumok/strumok_package.vhd
    Strumok/strumok_cipher.vhd
    Strumok/strumok_tb.vhd
    sim/timing_tb.vhd
)

ALL_TB=(rc4_tb gost_tb kuznyechik_tb kalyna_tb strumok_tb)
TBS=("${@:-${ALL_TB[@]}}")

echo "== analyse =="
for f in "${SOURCES[@]}"; do
    ghdl -a $STD --workdir="$WORK" "$f" || { echo "FAILED: $f"; exit 1; }
done

fail=0
for tb in "${TBS[@]}"; do
    echo
    echo "== $tb =="
    ghdl -e $STD --workdir="$WORK" "$tb" || { fail=1; continue; }
    ghdl -r $STD --workdir="$WORK" "$tb" --stop-time=1ms 2>&1 |
        sed 's/^.*(report [a-z]*): //'
    [ "${PIPESTATUS[0]}" -ne 0 ] && fail=1
done

echo
if [ $fail -eq 0 ]; then echo "ALL TESTBENCHES COMPLETED"; else echo "SOME TESTBENCHES FAILED"; fi
exit $fail
