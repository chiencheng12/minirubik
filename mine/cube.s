.data
input:   .asciz "21345671111111"
face_pm: .word 0, 10080, 20160   # pm 每個面 5040 格 × 2 byte = 10080 byte
face_om: .word 0, 1458, 2916     # om 每個面 729 格 × 2 byte = 1458 byte
face_lm: .word 0, 210, 420       # lm 每個面 210 格 × 1 byte = 210 byte
.align 2
weights: .word 720, 120, 24, 6, 2, 1
where:   .zero 8

.text
main:
    la   s0, input             # s0 = 輸入字串
    la   s1, weights           # s1 = 權重表
    la   s6, where             # s6 = where 表

# ========== 1. orient（方向，3 進位，取前 6 個）==========
    addi t0, s0, 7             # 從第 8 個字元開始
    li   t1, 0                 # orient
    li   t2, 6
orient_loop:
    lbu  t3, 0(t0)
    addi t3, t3, -49           # 字元 -> 0~2
    slli t4, t1, 1
    add  t1, t4, t1            # orient * 3
    add  t1, t1, t3
    addi t0, t0, 1
    addi t2, t2, -1
    bnez t2, orient_loop
    mv   s7, t1                # s7 = orient

# ========== 2. where（反查表：cubie 在哪個位置）==========
    mv   t0, s0
    li   t2, 0                 # i
    li   t3, 7
where_loop:
    lbu  t4, 0(t0)
    addi t4, t4, -49           # cubie 編號 0~6
    add  t5, s6, t4
    sb   t2, 0(t5)             # where[cubie] = i
    addi t2, t2, 1
    addi t0, t0, 1
    bne  t2, t3, where_loop

# ========== 3. place（用 where[0..2] 算）==========
    lbu  t0, 0(s6)             # a
    lbu  t1, 1(s6)             # b
    lbu  t2, 2(s6)             # c
    sltu t3, t0, t1            # b > a
    sub  t3, t1, t3            # b'
    sltu t4, t0, t2            # c > a
    sltu t5, t1, t2            # c > b（用原本的 b）
    sub  t4, t2, t4
    sub  t4, t4, t5            # c'
    slli t5, t0, 5
    slli t6, t0, 1
    sub  t5, t5, t6            # a * 30
    slli t6, t3, 2
    add  t6, t6, t3            # b' * 5
    add  s8, t5, t6
    add  s8, s8, t4            # s8 = place

# ========== 4. perm（Lehmer code，排列編號）==========
    li   s2, 0                 # perm
    li   s3, 0                 # i
    li   s4, 6                 # 外圈上限
    li   s5, 7                 # 內圈上限
outer:
    add  t0, s0, s3
    lbu  t1, 0(t0)             # input[i]
    li   t2, 0                 # 個數
    addi t3, s3, 1             # j = i + 1
inner:
    add  t4, s0, t3
    lbu  t5, 0(t4)
    sltu t5, t5, t1            # input[j] < input[i]
    add  t2, t2, t5
    addi t3, t3, 1
    bne  t3, s5, inner

    slli t4, s3, 2
    add  t4, s1, t4
    lw   t6, 0(t4)             # weights[i]
mul_loop:
    beqz t2, mul_done
    add  s2, s2, t6            # 個數 × 權重，重複加
    addi t2, t2, -1
    j    mul_loop
mul_done:
    addi s3, s3, 1
    bne  s3, s4, outer

# ========== M3: h = max(pdb_perm[perm], pdb_ol[place*729 + orient]) ==========
    la   t0, pdb_perm
    add  t0, t0, s2            # pdb_perm 起點 + perm
    lbu  s9, 0(t0)             # s9 = h_perm

    la   t0, place_base
    slli t1, s8, 2             # place * 4（place_base 每格 4 byte）
    add  t0, t0, t1
    lw   t1, 0(t0)             # t1 = place * 729
    add  t1, t1, s7            # t1 = index = place*729 + orient
    srli t2, t1, 1             # t2 = index / 2 = 哪一個 byte
    la   t0, pdb_ol
    add  t0, t0, t2
    lbu  t2, 0(t0)             # t2 = 裝著兩格的那個 byte
    andi t3, t1, 1             # t3 = index 是奇數(1)還是偶數(0)
    slli t3, t3, 2             # 偶數 -> 0，奇數 -> 4
    srl  t2, t2, t3            # 奇數就右移 4 bit
    andi t2, t2, 15            # 只留低 4 bit = h_ol
    bgeu s9, t2, h_done        # h_perm >= h_ol 就不用換
    mv   s9, t2                # 否則 s9 = h_ol
h_done:                        # s9 = h = 兩者較大的
   # ========== M4-b: 測試 turn 和 heur ==========
    mv   a2, s2                # 起始狀態 -> a2, a3, a4
    mv   a3, s7
    mv   a4, s8
    li   a5, 0                 # 面：0 = R, 1 = B, 2 = D
    jal  ra, turn              # 轉一次
    jal  ra, heur              # 算轉完的 h，放在 a6
    mv   a0, a6
    li   a7, 1
    ecall
    li   a7, 10
    ecall
    # ---------- turn：對 (a2, a3, a4) 轉一次面 a5 ----------
turn:
    slli t6, a5, 2             # t6 = 面 × 4

    la   t0, pm
    la   t1, face_pm
    add  t1, t1, t6
    lw   t1, 0(t1)
    add  t0, t0, t1            # pm 裡這個面的起點
    slli t2, a2, 1
    add  t0, t0, t2
    lhu  a2, 0(t0)             # a2 = 新 perm

    la   t0, om
    la   t1, face_om
    add  t1, t1, t6
    lw   t1, 0(t1)
    add  t0, t0, t1
    slli t2, a3, 1
    add  t0, t0, t2
    lhu  a3, 0(t0)             # a3 = 新 orient

    la   t0, lm
    la   t1, face_lm
    add  t1, t1, t6
    lw   t1, 0(t1)
    add  t0, t0, t1
    add  t0, t0, a4
    lbu  a4, 0(t0)             # a4 = 新 place
    ret

# ---------- heur：由 (a2, a3, a4) 算出 h，放在 a6 ----------
heur:
    la   t0, pdb_perm
    add  t0, t0, a2
    lbu  a6, 0(t0)             # a6 = h_perm

    la   t0, place_base
    slli t1, a4, 2
    add  t0, t0, t1
    lw   t1, 0(t0)             # place * 729
    add  t1, t1, a3            # index = place*729 + orient
    srli t2, t1, 1
    la   t0, pdb_ol
    add  t0, t0, t2
    lbu  t2, 0(t0)
    andi t3, t1, 1
    slli t3, t3, 2
    srl  t2, t2, t3
    andi t2, t2, 15            # t2 = h_ol
    bgeu a6, t2, heur_done
    mv   a6, t2                # a6 = 兩者較大的
heur_done:
    ret