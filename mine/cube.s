.data
input:  .asciz "21345671111111"

.text
main:
    la   t0, input
    lbu  t1, 0(t0)             # t1 = input[0]
    li   t2, 0                 # t2 = 個數
    li   t3, 1                 # t3 = j，從第 1 個字元開始
    li   t4, 7                 # j 的上限

inner:
    add  t5, t0, t3            # input[j] 的位址
    lbu  t6, 0(t5)
    sltu t6, t6, t1            # input[j] < input[0] ? 1 : 0
    add  t2, t2, t6            # 累加
    addi t3, t3, 1
    bne  t3, t4, inner

    mv   a0, t2
    li   a7, 1
    ecall
    li   a7, 10
    ecall