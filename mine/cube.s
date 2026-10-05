.data
input:   .asciz "76543211111111"
.align 2                       # 讓下面的 .word 對齊 4 byte，lw 才讀得到
weights: .word 720, 120, 24, 6, 2, 1

.text
main:
    la   s0, input
    la   s1, weights
    li   s2, 0                 # s2 = perm
    li   s3, 0                 # s3 = i
    li   s4, 6                 # 外圈上限
    li   s5, 7                 # 內圈上限

outer:
    add  t0, s0, s3
    lbu  t1, 0(t0)             # t1 = input[i]
    li   t2, 0                 # t2 = 個數
    addi t3, s3, 1             # j = i + 1

inner:
    add  t4, s0, t3
    lbu  t5, 0(t4)
    sltu t5, t5, t1            # input[j] < input[i] ?
    add  t2, t2, t5
    addi t3, t3, 1
    bne  t3, s5, inner

    slli t4, s3, 2             # i * 4（每個 word 4 byte）
    add  t4, s1, t4
    lw   t6, 0(t4)             # t6 = weights[i]

mul_loop:                      # 個數 × 權重：重複加
    beqz t2, mul_done
    add  s2, s2, t6
    addi t2, t2, -1
    j    mul_loop

mul_done:
    addi s3, s3, 1             # i++
    bne  s3, s4, outer

    mv   a0, s2
    li   a7, 1
    ecall
    li   a7, 10
    ecall