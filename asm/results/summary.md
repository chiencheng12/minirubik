# Measurement summary

Ripes continuous `v2.2.6-106-g5b8a616` (universal2), Apple Silicon, CLI.
Instruction counts are `--iret` with the renderer compiled out
(`build/cube_cli.s`). Raw per-state results are in `v*-dist11.tsv`.

## Retired instructions on RV32_ISS, all 2,644 distance-11 states

| Build | Worst | Worst state | Mean |
|---|---|---|---|
| C `fast.c`, `riscv64-elf-gcc -O2 -march=rv32i -mabi=ilp32` | 8,841,405 | 12347651111111 (host node count) | — |
| asm v1 | 4,155,843 | 12347651111111 | 556,558 |
| asm v2 | 3,134,465 | 12347651111111 | 424,023 |
| asm v3 (first try: last-level special case, reverted) | 3,185,492 on the worst state | — | — |
| asm v3 | 2,820,014 | 12347651111111 | 379,620 |

Pass condition: no distance-11 state above 5×10⁷ → v3 worst is 5.6% of it.

`21345671111111` (reported separately, not graded): C 2,047,324;
v1 991,496; v2 752,579; v3 675,044.

## Test cases on RV32_ISS and RV32_5S (v3)

| State | Solution | ISS iret | 5S iret | 5S cycles | 5S CPI |
|---|---|---|---|---|---|
| 12345671111111 (solved) | (empty line) | 631 | 630 | 752 | 1.19 |
| 13642571111111 (1 move) | D' | 796 | 795 | 952 | 1.20 |
| 21345671111111 (distance 11) | R B' D2 R' B R' B' R D2 R B | 675,044 | 675,043 | 817,013 | 1.21 |

The 5S count is one lower than ISS: the final exit `ecall` is not counted
as retired on the pipelined model.

## Size (renderer off, assembled with GNU as 2.47 for the byte count)

| | asm v3 | C reference |
|---|---|---|
| `.text` | 1,324 B (search loop `new_bound`..`found`: 492 B) | 1,308 B (`fast_solve` 1,188 B) |
| static data | 121,657 B (`.data`; tables 121,413 B) | 115,308 B (`.rodata`) |
| budget | ≤ 131,072 B | ≤ 131,072 B |
