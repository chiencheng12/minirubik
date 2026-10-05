.data
input:   .asciz "21345671111111"
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

# ========== 輸出：perm、orient、place 各一行 ==========
    mv   a0, s2
    li   a7, 1
    ecall
    li   a0, 10                # 換行
    li   a7, 11
    ecall

    mv   a0, s7
    li   a7, 1
    ecall
    li   a0, 10
    li   a7, 11
    ecall

    mv   a0, s8
    li   a7, 1
    ecall
    li   a0, 10
    li   a7, 11
    ecall

    li   a7, 10
    ecall