# RV32I assembly solver for Ripes

`cube.s` is the source. Ripes has no `.include` or `.if`, so `build.sh`
generates the tables (with `opt/gen_tables.c`, which also checks gates
H1, H2 and H4) and writes two self-contained programs:

| File | Renderer | Use |
|---|---|---|
| `build/cube_cli.s` | removed | `--iret` measurements |
| `build/cube_gui.s` | kept | LED Matrix animation in the Ripes GUI |

```sh
./build.sh                    # input 21345671111111
./build.sh 12347651111111     # another state (14 digits, as in solver.c)
Ripes --mode cli -t asm --src build/cube_cli.s --proc RV32_ISS --iret
```

To change the state by hand, edit the `input:` line near the top of the
generated file. The program prints the solution moves and exits with
code 0, or 2 for an invalid state.

**GUI**: select a processor, add *LED Matrix* in the I/O tab with
Height 25 and Width 35 *before* loading `build/cube_gui.s` (the program
uses `LED_MATRIX_0_BASE` / `_WIDTH`), then run and watch the I/O tab.

**All distance-11 states** (about 7 minutes, 8 Ripes processes):

```sh
cc -O2 -std=c99 -o ../opt/verify ../opt/verify.c ../opt/fast.c   # needs opt/tables.h (make -C ../opt)
../opt/verify list 11 | ./run_all.sh > results/dist11.tsv
../opt/verify check < results/dist11.tsv
```

`tools/led_test.py` checks every LED frame against a 3D model;
`tools/derive_net.py` derives the sticker layout from solver.c's tables.
Measured results are in `results/`, summarized in `results/summary.md`.
