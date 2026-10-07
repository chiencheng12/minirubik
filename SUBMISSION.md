# Submission map: assignment 1, phase 1

This repository is a fork of `sysprog21/minirubik` at commit
`231796cc48868f4ea276f652139b6bebbad0cd02`. The original files
(`solver.c`, `mini.c`, `Makefile`, `README.md`, `report.md`, ...) are
untouched. The write-up is my HackMD note; the AI usage disclosure at its
end says which parts were written by me and which by Claude.

## Where each required item is

| Required item | Where | Written by |
|---|---|---|
| Hand-written RV32I assembly | `mine/cube.s` (solver), `mine/tables.s` (generated tables), `mine/cube_full.s` (both joined; **load this one in Ripes**) | `mine/cube.s`: the first stages by me, the rest by Claude; tables: generated |
| C implementation of the final algorithm | `opt/fast.c`, `opt/fast.h`, `opt/host_main.c`, `opt/rv32_main.c`, `opt/Makefile` | Claude |
| Table generator (host) | `opt/gen_tables.c`, `opt/make_simple_tables.py` | Claude |
| Host gates H1, H2, H4 and H3 | `opt/gen_tables.c` (H1, H2, H4), `opt/check.c` (H3); run `make -C opt check`; output in `my-results/gates.txt` and `my-results/node-counts.txt` | Claude wrote the checks; I ran them |
| Target checks: all 2,644 distance-11 states solved optimally on `RV32_ISS`, worst case | `opt/verify.c`, `asm/run_all.sh`, `asm/run_one.sh`; results in `my-results/mine-dist11.tsv` and `my-results/mine-summary.txt` | Claude wrote the tools; I ran them |
| Test cases (solved, short scramble, distance 11) on `RV32_ISS` and `RV32_5S` | `my-results/mine-test-cases.txt` | I ran them |
| Ripes speed and memory measurements (Stage 1) | scripts in `stage1/`; results in `my-results/stage1-20261005.txt` | Claude wrote the scripts; I ran them |
| Heuristic comparison (Stage 2) | `experiments/pdb_explore.c`; results in `my-results/pdb-compare.txt` and `my-results/pdb-triples.txt` | Claude wrote the program; I ran it |
| GCC reference for the C version on Ripes | `my-results/c-ripes.txt` | I ran it |
| Memory sizes of the tables and the program | `my-results/mine-size.txt`, `my-results/mem-sections.txt`, `my-results/mem-symbols.txt` | I ran the tools |
| LED animation and the CLI / GUI split | `mine/render.s`, `mine/build_gui.sh`, `mine/build_cli.sh`, and the comment line `# @ANIMATE@` in `mine/cube.s` | Claude |

## How to run

    Ripes --mode cli -t asm --src mine/cube_full.s --proc RV32_ISS --iret
    make -C opt check

The state is the 14-digit string on the `input:` line of the assembly
file (see `mine/README.md`).

## Not part of the submission

`asm/` (an earlier, faster assembly solver written by Claude, with its
build and test tools) and the results of that earlier solver:
`my-results/size.txt`, `my-results/test-cases.txt`,
`my-results/v3-dist11.tsv`, `my-results/v3-summary.txt`. They are kept
unchanged for the history. Only `asm/run_all.sh` and `asm/run_one.sh`
are still used, as the batch runner for my own solver.
