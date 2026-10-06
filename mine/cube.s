.data
input:   .asciz "21345671111111"
.align 2
face_pm: .word 0, 10080, 20160   # pm 每個面 5040 格 × 2 byte = 10080 byte
face_om: .word 0, 1458, 2916     # om 每個面 729 格 × 2 byte = 1458 byte
face_lm: .word 0, 210, 420       # lm 每個面 210 格 × 1 byte = 210 byte
weights: .word 720, 120, 24, 6, 2, 1
where:   .zero 8
move_face: .byte 0, 0, 0, 1, 1, 1, 2, 2, 2   # 走法 m 對應的面
move_turn: .byte 1, 2, 3, 1, 2, 3, 1, 2, 3   # 走法 m 要轉幾次（1=X, 2=X2, 3=X'）
path:    .zero 12      
move_name: .string "R R2R'B B2B'D D2D'"   # 每個走法的名字，各佔 2 個字元                      # 記下解法的每一步
.align 2
frames:  .zero 96                            # 12 層 × 每層 8 byte

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
   # ========== M4-c: IDA* 搜尋 ==========
    la   s5, frames            # s5 = frames 起點
    la   s6, path              # s6 = path 起點
    mv   s3, s9                # s3 = bound，從起始 h 開始
    li   s11, 0                # 起始就解開的情況：長度 0
    beqz s3, search_done

new_bound:
    mv   s4, s5                # s4 = 目前這一層的框（第 0 層）
    li   s11, 0                # s11 = 深度 d
    sh   s2, 0(s4)             # 第 0 層放起始狀態
    sh   s7, 2(s4)
    sb   s8, 4(s4)
    li   t0, 3
    sb   t0, 5(s4)             # 上一步的面 = 3（沒有）
    sb   zero, 6(s4)           # 下一個要試的走法 = 0

search:
    lbu  t0, 6(s4)             # t0 = 走法 m（0..8）
    li   t1, 9
    beq  t0, t1, backtrack     # 9 種都試完了，退回上一層
    addi t1, t0, 1
    sb   t1, 6(s4)             # 這層下一次試 m + 1

    la   t1, move_face
    add  t1, t1, t0
    lbu  a5, 0(t1)             # a5 = 這個走法的面 f
    lbu  t1, 5(s4)             # t1 = 上一步的面
    beq  a5, t1, search        # 同一面不連轉，跳過

    add  t2, s6, s11
    sb   t0, 0(t2)             # path[d] = m（記下這一步）
    la   t1, move_turn
    add  t1, t1, t0
    lbu  s10, 0(t1)            # s10 = 要轉幾次（1..3）

    lhu  a2, 0(s4)             # 從這層的狀態開始轉
    lhu  a3, 2(s4)
    lbu  a4, 4(s4)
turn_loop:
    jal  ra, turn
    addi s10, s10, -1
    bnez s10, turn_loop

    jal  ra, heur              # a6 = 子節點的 h
    addi t0, s11, 1            # t0 = 已走步數 g = d + 1
    add  t0, t0, a6            # t0 = g + h
    bgtu t0, s3, search        # 超過 bound，放棄這條路

    or   t0, a2, a3            # perm 和 orient 都是 0 = 解開了
    beqz t0, found

    addi s4, s4, 8             # 往下一層：換到下一個框
    addi s11, s11, 1
    sh   a2, 0(s4)
    sh   a3, 2(s4)
    sb   a4, 4(s4)
    sb   a5, 5(s4)             # 記下這一層是轉哪個面來的
    sb   zero, 6(s4)
    j    search

backtrack:
    beqz s11, bound_up         # 已經在第 0 層，這個 bound 找不到
    addi s4, s4, -8            # 退回上一層
    addi s11, s11, -1
    j    search

bound_up:
    addi s3, s3, 1             # bound + 1，重新搜尋
    j    new_bound

found:
    addi s11, s11, 1           # s11 = 解的長度
search_done:

   # ========== M5: 印出解法 ==========
    li   t3, 0                 # t3 = i，第幾步
print_loop:
    beq  t3, s11, print_end    # 全部印完了
    beqz t3, no_space
    li   a0, 32                # 不是第一步：先印一個空格
    li   a7, 11
    ecall
no_space:
    add  t0, s6, t3
    lbu  t0, 0(t0)             # t0 = path[i] = 走法 m
    slli t0, t0, 1             # m × 2（每個名字佔 2 個字元）
    la   t1, move_name
    add  t1, t1, t0            # t1 = 這個走法的名字的位址
    lbu  a0, 0(t1)             # 第 1 個字元（R、B 或 D）
    li   a7, 11
    ecall
    lbu  a0, 1(t1)             # 第 2 個字元
    li   t2, 32
    beq  a0, t2, skip_second   # 是空格就不印
    li   a7, 11
    ecall
skip_second:
    addi t3, t3, 1
    j    print_loop
print_end:
    li   a0, 10                # 換行
    li   a7, 11
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