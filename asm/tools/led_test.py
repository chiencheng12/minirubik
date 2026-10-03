"""Check the LED renderer without the Ripes GUI.

Builds a test copy of build/cube_gui.s in which the LED matrix is ordinary
memory (LED_MATRIX_0_BASE = 0x20000000, 35 x 25), DELAY = 1, and every
`jal ra, render` is followed by a checksum of the whole matrix printed with
ecall 1.  Runs it on the Ripes CLI and compares each checksum with a frame
rendered independently here from the 3D model of derive_net.py.

    python3 tools/led_test.py 21345671111111 12347651111111 ...
"""
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()):
    import derive_net as dn

RIPES = "/Applications/Ripes.app/Contents/MacOS/Ripes"
W, H, BASE = 35, 25, 0x20000000
RGB = {"U": 0xFFFFFF, "D": 0xFFD500, "F": 0x009B48, "B": 0x0046AD,
       "R": 0xB71234, "L": 0xFF5800}
NAMES = ["R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"]


def frame(p, o):
    """Matrix for cubies p[0..6], twists o[0..6] (internal positions)."""
    m = [0] * (W * H)
    for pos in range(8):
        cubie = 0 if pos == 0 else p[pos - 1] + 1
        tw = 0 if pos == 0 else o[pos - 1]
        home = dn.corner_axes(cubie, dn.REF, dn.CCW)
        for slot, ax in enumerate(dn.corner_axes(pos, dn.REF, dn.CCW)):
            hax = home[(slot - tw) % 3]
            colour = RGB[dn.FACE_OF[(hax, dn.POS[cubie][hax])]]
            face = dn.FACE_OF[(ax, dn.POS[pos][ax])]
            col, row = dn.facelet_xy(face, dn.POS[pos])
            cx, cy = dn.NET[face]
            x0, y0 = cx * 9 + col * 4, cy * 7 + row * 3
            for y in range(y0, y0 + 3):
                for x in range(x0, x0 + 4):
                    m[y * W + x] = colour
    return m


def checksum(m):
    c = 0
    for v in m:
        c = (((c << 1) | (c >> 31)) + v) & 0xFFFFFFFF
    return c


def quarter(p, o, f):
    s, t = dn.SOURCE[f], dn.TWIST[f]
    return ([p[s[i]] for i in range(7)],
            [(o[s[i]] + t[i]) % 3 for i in range(7)])


SUM_ROUTINE = """
led_sum:                         # test only: checksum of the LED matrix
    li   t0, LED_MATRIX_0_BASE
    li   t1, 875
    li   a0, 0
led_sum_loop:
    slli t2, a0, 1
    srli a0, a0, 31
    or   a0, a0, t2
    lw   t2, 0(t0)
    add  a0, a0, t2
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, led_sum_loop
    li   a7, 1
    ecall
    li   a0, 10
    li   a7, 11
    ecall
    ret
"""


def run(state):
    here = os.path.join(os.path.dirname(__file__), "..")
    src = open(os.path.join(here, "build", "cube_gui.s")).read()
    src = src.replace('input:      .string "21345671111111"',
                      f'input:      .string "{state}"')
    src = src.replace(".equ DELAY, 30000", ".equ DELAY, 1")
    src = re.sub(r"^(    jal  ra, render\b.*)$", r"\1\n    jal  ra, led_sum",
                 src, flags=re.M)
    head = (f".equ LED_MATRIX_0_BASE, {BASE}\n"
            f".equ LED_MATRIX_0_WIDTH, {W}\n.equ LED_MATRIX_0_HEIGHT, {H}\n")
    src = head + src + SUM_ROUTINE
    with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
        f.write(src)
    out = subprocess.run([RIPES, "--mode", "cli", "-t", "asm", "--src",
                          f.name, "--proc", "RV32_ISS"],
                         capture_output=True, text=True).stdout
    os.unlink(f.name)
    lines = out.replace("\0", "").splitlines()
    sums = [int(x) & 0xFFFFFFFF for x in lines if x.lstrip("-").isdigit()]
    moves = next((x for x in lines if x and not x.lstrip("-").isdigit()), "")
    if moves.startswith("Program exited"):
        moves = ""
    return sums, moves.split()


def main():
    ok = True
    for state in sys.argv[1:]:
        sums, moves = run(state)
        p = [ord(c) - 49 for c in state[:7]]
        o = [ord(c) - 49 for c in state[7:]]
        want = [checksum(frame(p, o))]
        for mv in moves:
            k = NAMES.index(mv)
            for _ in range(k % 3 + 1):
                p, o = quarter(p, o, k // 3)
            want.append(checksum(frame(p, o)))
        solved = checksum(frame(list(range(7)), [0] * 7))
        good = sums == want and want[-1] == solved
        ok &= good
        print(f"{state}: {len(moves)} moves, {len(sums)} frames,",
              "OK" if good else f"MISMATCH\n  got  {sums}\n  want {want}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
