.data
input:  .asciz "21345671111111"
where:  .zero 8

.text
main:
    # ---- 先建 where 表（和上一題相同）----
    la   t0, input
    la   t1, where
    li   t2, 0
    li   t3, 7
loop:
    lbu  t4, 0(t0)
    addi t4, t4, -49
    add  t5, t1, t4
    sb   t2, 0(t5)
    addi t2, t2, 1
    addi t0, t0, 1
    bne  t2, t3, loop

    # ---- 讀出 a, b, c ----
    lbu  s0, 0(t1)             # a = where[0]
    lbu  s1, 1(t1)             # b = where[1]
    lbu  s2, 2(t1)             # c = where[2]

    # ---- b' = b - (b > a) ----
    sltu t4, s0, s1            # a < b，也就是 b > a
    sub  s3, s1, t4            # s3 = b'（s1 的原始 b 要保留）

    # ---- c' = c - (c > a) - (c > b) ----
    sltu t4, s0, s2            # c > a
    sltu t5, s1, s2            # c > b（用原始 b）
    sub  s4, s2, t4
    sub  s4, s4, t5            # s4 = c'

    # ---- place = a*30 + b'*5 + c' ----
    slli t4, s0, 5             # a * 32
    slli t5, s0, 1             # a * 2
    sub  t4, t4, t5            # a * 30
    slli t5, s3, 2             # b' * 4
    add  t5, t5, s3            # b' * 5
    add  a0, t4, t5
    add  a0, a0, s4            # + c'

    li   a7, 1                 # 印整數
    ecall
    li   a7, 10                # 結束
    ecall