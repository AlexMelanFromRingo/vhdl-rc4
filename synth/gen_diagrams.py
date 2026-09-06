#!/usr/bin/env python3
"""
Генерує SVG-діаграми проєкту: автомати керування та тракти даних.
Запуск:  python3 synth/gen_diagrams.py
Вихід:   docs/*.svg
"""
import subprocess, pathlib, textwrap

DOCS = pathlib.Path("docs"); DOCS.mkdir(exist_ok=True)

# Спільний стиль: світле тло, щоб однаково читалось у light/dark темах GitHub
HEAD = '''digraph G {{
  bgcolor="#fbfbfd";
  rankdir={rank};
  fontname="DejaVu Sans";
  node [fontname="DejaVu Sans", fontsize=11, shape=box, style="rounded,filled",
        color="#3d4a5c", fillcolor="#ffffff", penwidth=1.2];
  edge [fontname="DejaVu Sans", fontsize=9, color="#5a6a7d", penwidth=1.1,
        arrowsize=0.7];
  labelloc="t"; fontsize=14; label="{title}";
  nodesep=0.35; ranksep=0.45;
'''

CTRL  = 'fillcolor="#e8eefb", color="#3b5bab"'   # керування
DATA  = 'fillcolor="#eaf6ec", color="#2f7d43"'   # тракт даних
KEY   = 'fillcolor="#fdf0e3", color="#b06d1f"'   # розгортання ключа
TERM  = 'fillcolor="#f3e8fb", color="#7b3fa6"'   # спокій / завершення

def render(name, dot):
    p = DOCS / f"{name}.svg"
    subprocess.run(["dot", "-Tsvg", "-o", str(p)], input=dot, text=True, check=True)
    print(f"  {p}  ({p.stat().st_size} bytes)")

# ------------------------------------------------------------------ FSM
render("fsm_gost", HEAD.format(rank="LR", title="GOST 28147-89 — control FSM") + f'''
  IDLE  [{TERM}];
  ROUND [{CTRL}, label="ROUND_STEP\\nn1 ← n2 ⊕ f(n1, K[i])\\nn2 ← n1"];
  FIN   [{DATA}, label="FINISH\\ndone ← 1"];
  IDLE  -> ROUND [label="start"];
  ROUND -> ROUND [label="rnd < 31  (32 rounds)"];
  ROUND -> FIN   [label="rnd = 31\\nout ← (n2⊕f) ‖ n1"];
  FIN   -> IDLE;
}}''')

render("fsm_kuznyechik", HEAD.format(rank="LR", title="Kuznyechik — control FSM") + f'''
  IDLE [{TERM}];
  KS   [{KEY},  label="KS_STEP\\n32 Feistel steps on C₁…C₃₂\\nK₃…K₁₀ emitted every 8th step"];
  ENC  [{DATA}, label="ENC_ROUND\\n9 × L(S(X))"];
  DEC  [{DATA}, label="DEC_ROUND\\n9 × X(S⁻¹(L⁻¹))"];
  FIN  [{CTRL}, label="FINISH"];
  IDLE -> KS   [label="key_start"];
  KS   -> KS   [label="i < 32"];
  KS   -> IDLE [label="i = 32\\nkey_ready ← 1"];
  IDLE -> ENC  [label="start ∧ ¬decrypt"];
  IDLE -> DEC  [label="start ∧ decrypt"];
  ENC  -> ENC; DEC -> DEC;
  ENC  -> FIN  [label="⊞ K₁₀"];
  DEC  -> FIN  [label="rnd = 1"];
  FIN  -> IDLE;
}}''')

render("fsm_kalyna_key", HEAD.format(rank="LR", title="Kalyna — key expansion FSM (one EncipherRound per clock)") + f'''
  IDLE  [{TERM}];
  subgraph cluster_kt {{ label="auxiliary key Kt — 3 clocks"; fontsize=10; labelloc="b"; color="#d8a86a"; style=rounded;
    KTA [{KEY}, label="KE_KT_A\\n⊞ k₀, round"];
    KTB [{KEY}, label="KE_KT_B\\n⊕ k₁, round"];
    KTC [{KEY}, label="KE_KT_C\\n⊞ k₀, round → Kt"];
  }}
  subgraph cluster_ev {{ label="one even round key — 4 clocks, repeated Nr/2+1 times"; fontsize=10; labelloc="b"; color="#d8a86a"; style=rounded;
    PRE [{KEY}, label="KE_PRE\\nktᵣ ← Kt ⊞ tmv"];
    A   [{KEY}, label="KE_A\\nround(st ⊞ ktᵣ)"];
    B   [{KEY}, label="KE_B\\nround(st ⊕ ktᵣ)"];
    C   [{KEY}, label="KE_C\\nrk[r] ← st ⊞ ktᵣ"];
  }}
  ODD  [{KEY}, label="KE_ODD\\nrk[i] ← rot(rk[i−1])\\nby 2·Nb+3 bytes"];
  IDLE -> KTA [label="key_start"];
  KTA -> KTB -> KTC -> PRE -> A -> B -> C;
  C -> PRE [label="tmv ≪ 1, rotate key", constraint=false];
  C -> ODD [label="r = Nr"];
  ODD -> ODD [label="i < Nr−1"];
  ODD -> IDLE [label="key_ready ← 1"];
}}''')

render("fsm_kalyna_block", HEAD.format(rank="LR", title="Kalyna — block FSM (Nr+2 clocks per block)") + f'''
  IDLE [{TERM}];
  ENC  [{DATA}, label="ENC_ROUND\\nNr−1 × (round, ⊕ rk[i])"];
  DEC  [{DATA}, label="DEC_ROUND\\nNr−1 × (round⁻¹, ⊕ rk[i])"];
  FIN  [{CTRL}, label="FINISH\\ndone ← 1"];
  IDLE -> ENC [label="start ∧ ¬decrypt\\nst ← pt ⊞ rk[0]"];
  IDLE -> DEC [label="start ∧ decrypt\\nst ← ct ⊟ rk[Nr]"];
  ENC -> ENC; DEC -> DEC;
  ENC -> FIN [label="final round, ⊞ rk[Nr]"];
  DEC -> FIN [label="final round⁻¹, ⊟ rk[0]"];
  FIN -> IDLE;
}}''')

render("fsm_strumok", HEAD.format(rank="LR", title="Strumok — control FSM") + f'''
  IDLE [{TERM}];
  INI  [{KEY},  label="INIT_STEP\\n32 steps (2 passes × 16)\\nFSM output fed back into LFSR"];
  RUN  [{DATA}, label="RUN\\none 64-bit keystream word\\nper clock while en = 1"];
  IDLE -> INI [label="init"];
  INI  -> INI [label="cnt < 31"];
  INI  -> RUN [label="cnt = 31\\nready ← 1"];
  RUN  -> RUN [label="en"];
  RUN  -> INI [label="init  (re-key / new IV)"];
}}''')

# ------------------------------------------------------------- datapath
render("datapath_gost", HEAD.format(rank="TB", title="GOST 28147-89 — Feistel datapath (1 round / clock)") + f'''
  node [shape=box];
  N1 [{DATA}, label="N1  (32)"];
  N2 [{DATA}, label="N2  (32)"];
  ADD [{CTRL}, shape=oval, label="⊞ mod 2³²"];
  K   [{KEY},  label="subkey X[key_index(rnd)]\\n8 × 32-bit key register"];
  SB  [{CTRL}, label="S-box layer\\n8 × ROM 16×4  (flat 128×4)"];
  ROL [{CTRL}, shape=oval, label="≪ 11\\n(wiring only)"];
  XOR [{CTRL}, shape=oval, label="⊕"];
  N1 -> ADD; K -> ADD; ADD -> SB -> ROL -> XOR;
  N2 -> XOR;
  XOR -> N1 [label="new N1"];
  N1 -> N2 [label="new N2", constraint=false];
}}''')

render("datapath_kalyna", HEAD.format(rank="TB", title="Kalyna — SPN round (state = Nb columns × 8 rows of bytes)") + f'''
  IN  [{DATA}, label="state : Nb × 64 bit\\nbyte(row,col) = state(col)(8row+7..8row)"];
  SUB [{CTRL}, label="SubBytes\\nπ₀…π₃ by row mod 4\\nflat ROM 1024×8"];
  SR  [{CTRL}, label="ShiftRows\\nrow r shifted by r/(8/Nb)\\n(pure wiring)"];
  MC  [{CTRL}, label="MixColumns\\ncirculant MDS 8×8 over GF(2⁸)\\n8·Nb constant multipliers"];
  RK  [{KEY},  label="round key rk[i]"];
  OP  [{CTRL}, shape=oval, label="⊞ mod 2⁶⁴  (rounds 0, Nr)\\n⊕  (rounds 1…Nr−1)"];
  OUT [{DATA}, label="next state"];
  IN -> SUB -> SR -> MC -> OP -> OUT;
  RK -> OP;
}}''')

render("datapath_strumok", HEAD.format(rank="LR", title="Strumok — LFSR over GF(2⁶⁴) + finite state machine") + f'''
  subgraph cluster_l {{ label="LFSR: 16 × 64 bit"; fontsize=10; labelloc="b"; color="#7fae8c"; style=rounded;
    S0 [{DATA}, label="S[i]"]; S11 [{DATA}, label="S[i+11]"];
    S13 [{DATA}, label="S[i+13]"]; S1 [{DATA}, label="S[i+1]"];
  }}
  AM  [{CTRL}, shape=oval, label="α ·\\n(≪8 ⊕ ROM)"];
  AI  [{CTRL}, shape=oval, label="α⁻¹ ·\\n(≫8 ⊕ ROM)"];
  FB  [{CTRL}, shape=oval, label="⊕"];
  R1  [{KEY}, label="R1"]; R2 [{KEY}, label="R2"];
  T   [{CTRL}, label="T = MixColumns(SubBytes(·))\\n— reused from Kalyna"];
  ADD [{CTRL}, shape=oval, label="⊞ mod 2⁶⁴"];
  OUT [{DATA}, label="z  (64 bit / clock)"];
  S0 -> AM -> FB; S11 -> AI -> FB; S13 -> FB;
  FB -> S0 [label="new S[i]"];
  S13 -> ADD [label=" "]; R2 -> ADD; ADD -> R1 [label="R1′"];
  R1 -> T -> R2 [label="R2′"];
  R1 -> OUT; FB -> OUT; R2 -> OUT; S1 -> OUT;
}}''')

print("done")
