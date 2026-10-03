# minirubik: optimal 2x2x2 solver in RV32I for Ripes (IDA* + pattern DBs)
#
# This is the source file. Ripes has no .include and no .if, so build.sh
# pastes in the tables (at the TABLES marker) and produces
#   build/cube_cli.s   renderer removed  (measure with --iret)
#   build/cube_gui.s   renderer kept     (LED matrix animation)
# Lines between "#@RENDER_BEGIN" and "#@RENDER_END" are the renderer.
#
# State coordinates (same as opt/fast.c):
#   perm   0..5039  Lehmer rank of the 7 cubies
#   orient 0..728   base-3 value of the first 6 twists
#   place  0..209   positions of cubies 0, 1, 2
# Heuristic h = max(pdb_perm[perm], pdb_ol[place_base[place] + orient]).
#
# Output: the solution moves separated by spaces (ecall 11, one char at a
# time, because ecall 4 in Ripes also prints the NUL terminator).
# Exit code (ecall 93): 0 = solved, 2 = invalid input.

.equ PM_FACE, 10080          # bytes per face in pm (5040 halves)
.equ OM_FACE, 1458           # bytes per face in om (729 halves)
.equ LM_FACE, 210            # bytes per face in lm (210 bytes)
.equ NO_FACE, 3

.data
# ---- input: 7 cubie digits then 7 twist digits, as in solver.c ----
input:      .string "21345671111111"

.align 2
# Search stack, one 8-byte frame per depth 0..11:
#   +0 perm (half)  +2 orient (half)  +4 place  +5 face  +6 turns  +7 last face
frames:     .zero 96
face_ptr:   .zero 36             # per face: &pm[f], &om[f], &lm[f]
lehmer_w:   .half 720, 120, 24, 6, 2, 1
pbuf:       .zero 8              # parsed cubie digits
where:      .zero 8              # where[c] = position of cubie c
move_name:  .string "R R2R'B B2B'D D2D'"

.align 2
# @TABLES@

.text
main:
    # ---- table bases kept in saved registers for the whole search ----
    la   s1, pm
    la   s2, om
    la   s3, lm
    la   s4, pdb_perm
    la   s5, pdb_ol
    la   s6, place_base
    la   s8, frames

    # face_ptr[f] = (pm + f*PM_FACE, om + f*OM_FACE, lm + f*LM_FACE)
    la   t0, face_ptr
    mv   t1, s1
    mv   t2, s2
    mv   t3, s3
    li   t4, 3
fp_loop:
    sw   t1, 0(t0)
    sw   t2, 4(t0)
    sw   t3, 8(t0)
    li   t5, PM_FACE
    add  t1, t1, t5
    addi t2, t2, OM_FACE
    addi t3, t3, LM_FACE
    addi t0, t0, 12
    addi t4, t4, -1
    bnez t4, fp_loop

# ======================= parse and validate =======================
    la   t0, input
    li   t1, 0                   # i
    li   t2, 0                   # bit mask of cubies seen
    la   t3, pbuf
    la   t4, where
parse_perm:
    lbu  t5, 0(t0)
    addi t5, t5, -49             # digit - '1'
    li   t6, 6
    bgtu t5, t6, invalid         # also catches characters below '1'
    srl  t6, t2, t5
    andi t6, t6, 1
    bnez t6, invalid             # duplicate cubie
    li   t6, 1
    sll  t6, t6, t5
    or   t2, t2, t6
    sb   t5, 0(t3)               # pbuf[i] = cubie
    add  t6, t4, t5
    sb   t1, 0(t6)               # where[cubie] = i
    addi t0, t0, 1
    addi t3, t3, 1
    addi t1, t1, 1
    li   t6, 7
    blt  t1, t6, parse_perm

    li   a0, 0                   # sum of twists
    li   a1, 0                   # orient coordinate
    li   t1, 0
parse_twist:
    lbu  t5, 0(t0)
    addi t5, t5, -49
    li   t6, 2
    bgtu t5, t6, invalid
    add  a0, a0, t5
    li   t6, 6
    bge  t1, t6, twist_done      # the 7th twist is implied
    slli t6, a1, 1               # orient = orient * 3 + twist
    add  a1, a1, t6
    add  a1, a1, t5
twist_done:
    addi t0, t0, 1
    addi t1, t1, 1
    li   t6, 7
    blt  t1, t6, parse_twist
    lbu  t5, 0(t0)
    bnez t5, invalid             # exactly 14 characters
    li   t6, 3
sum_mod3:                        # sum % 3 without division (sum <= 14)
    blt  a0, t6, sum_done
    addi a0, a0, -3
    j    sum_mod3
sum_done:
    bnez a0, invalid             # twist invariant violated

    # Lehmer rank: sum over i of smaller(i) * (6-i)!, smaller(i) <= 6,
    # multiplied by selecting 1x, 2x, 4x of the weight with masks.
    li   a2, 0                   # rank
    la   t0, pbuf
    la   t1, lehmer_w
    li   t2, 0                   # i
lehmer_i:
    lbu  t3, 0(t0)               # p[i]
    li   t4, 0                   # smaller
    addi t5, t0, 1
    la   t6, pbuf
    addi t6, t6, 7               # end of pbuf
lehmer_j:
    lbu  a3, 0(t5)
    sltu a3, a3, t3
    add  t4, t4, a3
    addi t5, t5, 1
    blt  t5, t6, lehmer_j
    lhu  a3, 0(t1)               # weight
    andi a4, t4, 1
    neg  a4, a4
    and  a4, a4, a3
    add  a2, a2, a4
    slli a3, a3, 1
    andi a4, t4, 2
    srli a4, a4, 1
    neg  a4, a4
    and  a4, a4, a3
    add  a2, a2, a4
    slli a3, a3, 1
    andi a4, t4, 4
    srli a4, a4, 2
    neg  a4, a4
    and  a4, a4, a3
    add  a2, a2, a4
    addi t0, t0, 1
    addi t1, t1, 2
    addi t2, t2, 1
    li   a3, 6
    blt  t2, a3, lehmer_i

    # place = a*30 + b'*5 + c', a, b, c = positions of cubies 0, 1, 2
    la   t0, where
    lbu  t1, 0(t0)               # a
    lbu  t2, 1(t0)               # b
    lbu  t3, 2(t0)               # c
    sltu t4, t1, t2
    sub  t4, t2, t4              # b' = b - (b > a)
    sltu t5, t1, t3
    sub  t5, t3, t5
    sltu t6, t2, t3
    sub  t5, t5, t6              # c' = c - (c > a) - (c > b)
    slli a3, t1, 5
    slli t1, t1, 1
    sub  a3, a3, t1              # 30a = 32a - 2a
    slli t6, t4, 2
    add  t4, t4, t6              # 5b'
    add  a3, a3, t4
    add  a3, a3, t5              # place

    # frame 0 = start state
    sh   a2, 0(s8)
    sh   a1, 2(s8)
    sb   a3, 4(s8)
    li   t0, NO_FACE
    sb   t0, 7(s8)

    # h of the start state; 0 means already solved
    srli t0, a2, 1
    add  t0, s4, t0
    lbu  t0, 0(t0)
    andi t1, a2, 1
    slli t1, t1, 2
    srl  t0, t0, t1
    andi t0, t0, 15              # h_perm
    slli t1, a3, 2
    add  t1, s6, t1
    lw   t1, 0(t1)
    add  t1, t1, a1              # place * 729 + orient
    srli t2, t1, 1
    add  t2, s5, t2
    lbu  t2, 0(t2)
    andi t1, t1, 1
    slli t1, t1, 2
    srl  t2, t2, t1
    andi t2, t2, 15              # h_ol
    bgeu t0, t2, h0_max
    mv   t0, t2
h0_max:
    beqz t0, print_empty
    mv   s7, t0                  # bound = h(start)

# ============================ IDA* ============================
# Registers during the search:
#   s0  frame of the node being expanded (depth d)
#   s7  bound          s9  face f of the current child
#   s10 turns of f applied to the child (1..3 = X, X2, X')
#   s11 rem = bound - (d + 1): largest h a child may have
#   a1, a2, a3  &pm[f], &om[f], &lm[f]
#   a4, a5, a6  child perm, orient, place
new_bound:
    mv   s0, s8
    addi s11, s7, -1
    li   s9, 0

face_setup:                      # start face s9 of the node at s0
    lbu  t0, 7(s0)
    bne  s9, t0, face_ok
    addi s9, s9, 1               # skip the face that led here
face_ok:
    li   t0, 3
    bgeu s9, t0, backtrack
    slli t0, s9, 3
    slli t1, s9, 2
    add  t0, t0, t1              # f * 12
    la   t1, face_ptr
    add  t0, t0, t1
    lw   a1, 0(t0)
    lw   a2, 4(t0)
    lw   a3, 8(t0)
    lhu  a4, 0(s0)               # child starts as a copy of the node
    lhu  a5, 2(s0)
    lbu  a6, 4(s0)
    li   s10, 0

gen_child:                       # one more quarter turn of face f
    slli t0, a4, 1
    add  t0, a1, t0
    lhu  a4, 0(t0)
    slli t0, a5, 1
    add  t0, a2, t0
    lhu  a5, 0(t0)
    add  t0, a3, a6
    lbu  a6, 0(t0)
    addi s10, s10, 1

    srli t0, a4, 1               # h_perm = nibble(pdb_perm, perm)
    add  t0, s4, t0
    lbu  t0, 0(t0)
    andi t1, a4, 1
    slli t1, t1, 2
    srl  t0, t0, t1
    andi t0, t0, 15
    bgt  t0, s11, next_child     # prune: g + h > bound

    slli t1, a6, 2               # h_ol = nibble(pdb_ol, place_base[place] + orient)
    add  t1, s6, t1
    lw   t1, 0(t1)
    add  t1, t1, a5
    srli t2, t1, 1
    add  t2, s5, t2
    lbu  t2, 0(t2)
    andi t1, t1, 1
    slli t1, t1, 2
    srl  t2, t2, t1
    andi t2, t2, 15
    bgt  t2, s11, next_child

    or   t0, a4, a5              # perm == 0 and orient == 0: solved
    beqz t0, found

    sb   s9, 5(s0)               # descend: remember where we were
    sb   s10, 6(s0)
    addi s0, s0, 8
    sh   a4, 0(s0)
    sh   a5, 2(s0)
    sb   a6, 4(s0)
    sb   s9, 7(s0)               # last face of the new node
    addi s11, s11, -1
    li   s9, 0
    j    face_setup

next_child:
    li   t0, 3
    blt  s10, t0, gen_child
    addi s9, s9, 1
    j    face_setup

backtrack:
    beq  s0, s8, bound_up
    addi s0, s0, -8
    addi s11, s11, 1
    lbu  s9, 5(s0)
    lbu  s10, 6(s0)
    slli t0, s9, 3               # restore face pointers and the child
    slli t1, s9, 2
    add  t0, t0, t1
    la   t1, face_ptr
    add  t0, t0, t1
    lw   a1, 0(t0)
    lw   a2, 4(t0)
    lw   a3, 8(t0)
    lhu  a4, 8(s0)
    lhu  a5, 10(s0)
    lbu  a6, 12(s0)
    j    next_child

bound_up:
    addi s7, s7, 1
    j    new_bound

found:
    sb   s9, 5(s0)
    sb   s10, 6(s0)
    addi s0, s0, 8               # s0 = end of the solution frames

# ========================== output ==========================
# move index = face * 3 + turns - 1; its name is 2 chars at move_name + 2*idx
print_moves:
    mv   t3, s8
    la   t4, move_name
print_loop:
    lbu  t0, 5(t3)
    lbu  t1, 6(t3)
    slli t2, t0, 1
    add  t0, t0, t2
    add  t0, t0, t1
    addi t0, t0, -1
    slli t0, t0, 1
    add  t5, t4, t0
    lbu  a0, 0(t5)
    li   a7, 11
    ecall
    lbu  a0, 1(t5)
    li   t6, 32
    beq  a0, t6, print_sep
    ecall
print_sep:
    addi t3, t3, 8
    beq  t3, s0, print_end
    li   a0, 32
    ecall
    j    print_loop

print_empty:
print_end:
    li   a0, 10
    li   a7, 11
    ecall
    li   a0, 0
    li   a7, 93
    ecall

invalid:
    li   a0, 2
    li   a7, 93
    ecall
