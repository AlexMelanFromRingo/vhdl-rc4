# Symmetric Ciphers in VHDL

Synthesisable RTL implementations of five symmetric ciphers — the Ukrainian
DSTU standards, their Russian GOST counterparts, and RC4 as a baseline — each
with a self-checking testbench validated against published test vectors.

![VHDL](https://img.shields.io/badge/VHDL-2008-1f6feb)
![GHDL](https://img.shields.io/badge/simulator-GHDL_4.1-2ea043)
![tests](https://img.shields.io/badge/assertions-102_passing-2ea043)
![vectors](https://img.shields.io/badge/vectors-RFC_7801_·_RFC_8891_·_DSTU_7624_·_DSTU_8845-8957e5)

---

## What's here

| Cipher | Standard | Structure | Block / Key | Rounds | Status |
|---|---|---|---|---|---|
| **Kalyna** (Калина) | DSTU 7624:2014 🇺🇦 | SPN | 128·256·512 / 128·256·512 | 10 / 14 / 18 | ✅ all 5 variants |
| **Strumok** (Струмок) | DSTU 8845:2019 🇺🇦 | LFSR + FSM (SNOW 2.0 family) | stream / 256·512 | — | ✅ 256 & 512 |
| **Kuznyechik** (Кузнечик) | GOST R 34.12-2015 🇷🇺 | SPN | 128 / 256 | 10 | ✅ |
| **Magma / GOST** | GOST 28147-89 🇷🇺 | Feistel | 64 / 256 | 32 | ✅ 3 S-box sets |
| **RC4** | — | stream | stream / 8–2048 | — | ✅ baseline |

All five share one `crypto_util` package for GF(2⁸) arithmetic and hex
formatting. Kalyna's tables are reused directly by Strumok (see below).

---

## Quick start

```bash
sudo apt install ghdl          # GHDL 4.1 (mcode) is enough
./sim/run_all.sh               # analyse everything, run every testbench
./sim/run_all.sh kalyna_tb     # or just one
```

Expected tail:

```
=== GOST 28147-89: ALL TESTS PASSED ===
=== Kuznyechik: ALL TESTS PASSED ===
=== Kalyna: ALL TESTS PASSED (5 variants, enc+dec) ===
=== Strumok: ALL TESTS PASSED (256 & 512, 8 DSTU vectors) ===
ALL TESTBENCHES COMPLETED
```

Every core is plain VHDL-2008 with no vendor primitives, so it also drops into
Quartus or Vivado unchanged.

---

## Layout

```
common/crypto_util.vhd        GF(2^8) multiply (parametrised polynomial), to_hex
GOST_28147_89/                gost_package · gost_cipher · gost_tb
Kuznyechik/                   kuznyechik_package · kuznyechik_cipher · kuznyechik_tb
Kalyna/                       kalyna_package · kalyna_cipher · kalyna_tb
Strumok/                      strumok_package · strumok_cipher · strumok_tb
RC4_Inside_Project_Directory/ the original RC4 lab (untouched)
sim/run_all.sh                GHDL build + run driver
```

Each cipher follows the same three-file shape: a **package** holding tables and
pure transformation functions, a **core** with an FSM that spends one clock per
round, and a **self-checking testbench** that reports `PASS`/`FAIL` per vector
and fails the simulation if anything is wrong.

---

## Design notes

**One generic module covers all of Kalyna.** `Nb` and `Nk` are generics, the
state is an unconstrained `array (natural range <>) of unsigned(63 downto 0)`,
and every transformation derives its geometry from `state'length`. All five
standard variants — 128/128, 128/256, 256/256, 256/512, 512/512 — are the same
architecture instantiated differently. The state is stored as *columns*: byte
`(row, col)` lives in `state(col)(8*row+7 downto 8*row)`, matching the reference
implementation exactly, so vectors compare unambiguously.

**Tables are computed at elaboration, not typed in.** Anything derivable is
derived by a pure function:

- Kuznyechik's `PI_INV` is inverted from `PI`; its 32 iteration constants
  `C_ITER(i) = L(Vec128(i))` are computed once, so the synthesised design gets a
  ROM instead of a second `L` block.
- Kalyna's four inverse S-boxes are inverted from the forward ones.
- Both Kalyna MDS matrices are **circulant**, so only the first row is stored.
- Strumok's `ALPHA_MUL` / `ALPHA_MUL_INV` are generated from a single 64-bit
  constant each, because `b ↦ ALPHA_MUL[b]` is GF(2⁸)-linear.

**Strumok reuses Kalyna's tables.** Strumok's `T` transform turns out to be
exactly Kalyna's `MixColumns(SubBytes(·))` applied to one 64-bit column:

```
T_j[b][row] == gf_mul(SBOX_ENC[j mod 4][b], MDS[row][j])
```

verified for all 8·256 entries. So `strumok_package` calls `kalyna_package`
directly rather than carrying its own `T0..T7` tables. Together with the α-table
trick, that removes about **2560 64-bit constants** (~180 KB of source) that a
literal port of the reference code would have needed.

**Kalyna adds round keys modulo 2⁶⁴, not by XOR** (first and last rounds) —
mixing two algebraic groups is a deliberate DSTU design choice, and it is why
decryption needs a real subtractor rather than the same XOR again.

---

## Timing

Measured by `sim/timing_tb.vhd`, which counts clock cycles between `key_start`
and `key_ready` and between `start` and `done` (handshake cycles included).
These are RTL latencies — no synthesis run has been done, so *f*max is unknown
and no bit/s figures are claimed.

| Core | Key setup | Per block | Throughput |
|---|---|---|---|
| GOST 28147-89 | none | 35 cycles / 64 bits | 1.8 bits/cycle |
| Kuznyechik | 34 cycles | 13 cycles / 128 bits | 9.8 bits/cycle |
| Kalyna-128/128 | 34 cycles | 13 cycles / 128 bits | 9.8 bits/cycle |
| Kalyna-512/512 | 54 cycles | 21 cycles / 512 bits | 24.4 bits/cycle |
| Strumok-256 | 34 cycles | 1 cycle / 64 bits | 64 bits/cycle |
| RC4 † | 512 cycles | 5 cycles / 8 bits | 1.6 bits/cycle |

† RC4 figures are read off its FSM rather than measured — its byte-serial
interface doesn't fit the same harness.

Kuznyechik and Kalyna expand the key once and keep the round keys, so subsequent
blocks do not pay for it again. Strumok sustains one 64-bit keystream word per
clock, which is what makes it the fastest core here by a wide margin — the
price is that its `T` transform sits on the critical path every cycle.

Run it yourself:

```bash
ghdl -r --std=08 --workdir=sim/work timing_tb
```

---

## Verification

102 assertions, 0 failures (RC4 included). Where the vectors come from:

| Cipher | Source |
|---|---|
| Kuznyechik | **RFC 7801** — full block plus the standard's worked `S`, `L`, `L⁻¹` examples |
| GOST 28147-89 | **RFC 8891** (Magma) with the TC26-Z S-box; other S-box sets from a model validated against it |
| Kalyna | reference implementation by the standard's authors ([rkiyanchuk/kalyna](https://github.com/rkiyanchuk/kalyna)), all 10 vectors |
| Strumok | **DSTU 8845:2019 Annex D**, vectors D.1.1.1–D.1.1.4 for both key sizes |
| RC4 | the two classic `Key`/`Plaintext` and `Wiki`/`pedia` vectors |

The Kalyna and Strumok testbenches are **generated** from the vector tables so
that no digit is retyped by hand.

Because DSTU has no RFC and no machine-readable release, every Strumok vector
was additionally cross-checked against **two independent implementations** —
[li0ard/strumok](https://github.com/li0ard/strumok) (TypeScript) and
[outspace/dstu8845](https://github.com/outspace/dstu8845) (C) — before being
committed. The Russian standards, by contrast, could be taken straight from
their RFCs.

> ⚠️ **Correction.** The planning note in this repo
> (`Составь подробный TODO список...md`) gives the GOST 28147-89 test-parameters
> vector as `CE AC 6C 0A 76 68 7D B2`. That value is wrong. A model validated
> against the official RFC 8891 Magma vector produces `12610BE2A6C2FDC9`
> (as `a1‖a0`) for a zero key and zero plaintext. The testbench uses the
> corrected value.

---

## Port conventions

Byte order is the usual trap with these standards, so each core states it explicitly:

- **GOST 28147-89** — `key_in(255:224)` = X0 … `key_in(31:0)` = X7;
  `data_in(63:32)` = N2 (high, `a1`), `data_in(31:0)` = N1 (low, `a0`).
  Feed it the RFC 8891 hex strings verbatim.
- **Kuznyechik** — `key_in(255:128)` = K1, `key_in(127:0)` = K2; block is
  big-endian as printed in RFC 7801.
- **Kalyna** — little-endian word array: word *i* occupies bits `64i+63 … 64i`,
  matching the reference `uint64_t[]` layout.
- **Strumok** — big-endian words: `K0` and `V0` sit in the most significant bits,
  so a key written as a hex string maps straight onto the port.

---

## References

- **DSTU 7624:2014** — Kalyna. Oliynykov, Gorbenko, Kazymyrov et al.,
  *[A New Encryption Standard of Ukraine: The Kalyna Block Cipher](https://eprint.iacr.org/2015/650)* (ePrint 2015/650)
- **DSTU 8845:2019** — Strumok stream cipher
- **RFC 7801** — GOST R 34.12-2015 (Kuznyechik)
- **RFC 8891** — GOST R 34.12-2015 (Magma, 64-bit block)
- **RFC 5830** — GOST 28147-89
- **RFC 4357** — CryptoPro S-box parameter sets

---

## Licence & scope

University coursework, published for reference. RC4 and GOST 28147-89 are here
for study and comparison — neither is appropriate for protecting anything real.
