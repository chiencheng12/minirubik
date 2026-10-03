"""Derive the sticker model behind solver.c's move tables.

Positions follow README.md (0 = front-upper-left anchor, 1..7 = the seven
movable seats; solver.c indexes them as 0..6).  Every corner is a point
(x, y, z) with x: L=-1/R=+1, y: D=-1/U=+1, z: B=-1/F=+1, and each of its
three stickers is the axis it faces.  The script
  1. checks that 90-degree clockwise turns of R, B, D reproduce source[][],
  2. searches for the orientation convention (reference axis + slot order)
     that reproduces twist[][],
  3. prints the 24 facelets of the unfolded net for the LED renderer.
"""
import itertools

POS = {0: (-1, 1, 1), 1: (1, 1, 1), 2: (1, -1, 1), 3: (-1, -1, 1),
       4: (1, 1, -1), 5: (1, -1, -1), 6: (-1, -1, -1), 7: (-1, 1, -1)}
SOURCE = [[1, 4, 2, 0, 3, 5, 6], [0, 1, 2, 4, 5, 6, 3], [0, 2, 5, 3, 1, 4, 6]]
TWIST = [[1, 2, 0, 2, 1, 0, 0], [0, 0, 0, 1, 2, 1, 2], [0, 0, 0, 0, 0, 0, 0]]
FACES = [("R", 0, 1), ("B", 2, -1), ("D", 1, -1)]   # axis index, sign
AXES = [0, 1, 2]


def rot(v, axis, sign):
    """Rotate v by 90 degrees clockwise as seen from outside the face on
    `axis` with outward direction `sign`."""
    x, y, z = v
    # clockwise seen from +axis = rotation by -90 degrees about +axis
    if axis == 0:
        y, z = z, -y
    elif axis == 1:
        z, x = x, -z
    else:
        x, y = y, -x
    if sign < 0:   # seen from the negative side: undo twice = opposite turn
        return rot(rot((x, y, z), axis, 1), axis, 1)
    return (x, y, z)


def pos_of(pt):
    return next(k for k, v in POS.items() if v == pt)


# 1. Permutation part: dest position gets the cubie from source position.
for f, (name, axis, sign) in enumerate(FACES):
    src = {}
    for p, pt in POS.items():
        if pt[axis] != sign:
            continue
        src[pos_of(rot(pt, axis, sign))] = p
    expect = {i + 1: SOURCE[f][i] + 1 for i in range(7) if SOURCE[f][i] != i}
    assert src == expect, (name, src, expect)
print("source[][] matches clockwise R, B, D turns")


# 2. Orientation convention.  Slots of a corner are its three axes in some
# cyclic order; twist o means the cubie's reference sticker sits in slot o.
def corner_axes(p, ref, ccw):
    """Axes of position p as slot 0, 1, 2: slot 0 is `ref`; the other two
    follow clockwise (or counter-clockwise) around the corner."""
    pt = POS[p]
    others = [a for a in AXES if a != ref]
    a, b = others
    # orientation of (ref, a, b) as seen from outside the corner
    m = [[0] * 3 for _ in range(3)]
    for row, ax in enumerate((ref, a, b)):
        m[row][ax] = pt[ax]
    det = (m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
           - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
           + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]))
    order = [ref, a, b] if (det > 0) != ccw else [ref, b, a]
    return order


def axis_of(vec):
    return next(i for i in AXES if vec[i] != 0)


found = None
for ref, ccw in itertools.product(AXES, (False, True)):
    ok = True
    for f, (name, axis, sign) in enumerate(FACES):
        for p, pt in POS.items():
            if pt[axis] != sign:
                continue
            d = pos_of(rot(pt, axis, sign))
            # sticker in slot 0 at p (the reference axis) moves to which slot at d
            unit = [0, 0, 0]
            unit[ref] = pt[ref]
            moved = rot(tuple(unit), axis, sign)
            slot = corner_axes(d, ref, ccw).index(axis_of(moved))
            if TWIST[f][d - 1] != slot:
                ok = False
    if ok:
        found = (ref, ccw)
        break
assert found, "no convention reproduces twist[][]"
REF, CCW = found
print("twist[][] matches: reference axis", "xyz"[REF],
      "slots", "counter-clockwise" if CCW else "clockwise")

# Colour of each face in the solved cube.
FACE_OF = {(0, 1): "R", (0, -1): "L", (1, 1): "U", (1, -1): "D",
           (2, 1): "F", (2, -1): "B"}

# 3. Net layout: face -> (cell column, cell row) in a 4 x 3 grid, and the
# 2 x 2 facelet coordinates (col, row) of a corner on that face.
NET = {"U": (1, 0), "L": (0, 1), "F": (1, 1), "R": (2, 1), "B": (3, 1),
       "D": (1, 2)}


def facelet_xy(face, pt):
    x, y, z = pt
    c = lambda v: 0 if v < 0 else 1   # -1 -> 0, +1 -> 1
    r = lambda v: 0 if v > 0 else 1   # +1 (up / back) -> top row
    if face == "F": return c(x), r(y)
    if face == "B": return 1 - c(x), r(y)
    if face == "R": return 1 - c(z), r(y)
    if face == "L": return c(z), r(y)
    if face == "U": return c(x), c(z)          # back row on top
    if face == "D": return c(x), 1 - c(z)      # front row on top


print("\n# facelet: position slot face col row -> pixel x y")
rows = []
for p in range(8):
    for slot, ax in enumerate(corner_axes(p, REF, CCW)):
        face = FACE_OF[(ax, POS[p][ax])]
        col, row = facelet_xy(face, POS[p])
        cx, cy = NET[face]
        px, py = cx * 9 + col * 4, cy * 7 + row * 3
        rows.append((p, slot, face, px, py))
        print(f"  {p} {slot} {face} {col} {row} -> {px:2d} {py:2d}")

print("\n# home colour of each cubie's slots (cubie = home position)")
for p in range(8):
    print(" ", p, [FACE_OF[(ax, POS[p][ax])]
                   for ax in corner_axes(p, REF, CCW)])
