# My RV32I solver for Ripes

`cube_full.s` is the complete program in one file (`cube.s` followed by
`tables.s`) and can be loaded into Ripes directly. Ripes has no
`.include`, so `build_cli.sh` regenerates it by joining the two files.

Run it on the Ripes command line (RV32I only, no extensions):

    Ripes --mode cli -t asm --src mine/cube_full.s --proc RV32_ISS --iret

The state to solve is the 14-digit string on the `input:` line near the
top of the file (same format as the baseline `solver.c`). The program
prints the moves of an optimal solution; `--iret` adds the number of
retired instructions.

| File | What it is |
|---|---|
| `cube.s` | the solver (read input, compute coordinates, heuristic, IDA*, print) |
| `tables.s` | generated lookup tables (data only; `opt/make_simple_tables.py`) |
| `cube_full.s` | `cube.s` + `tables.s`, ready to run |
| `render.s`, `build_gui.sh` | LED animation; `build_gui.sh` produces `build/cube_gui.s` for the Ripes GUI (add an LED Matrix with Height 25 and Width 35 first) |

Results are in `my-results/`. Which parts were written by me and which
by Claude is described in the AI usage disclosure of my HackMD note.
