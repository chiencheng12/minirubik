.data
input:  .asciz "12345672311111"

.text
main:
    la   t0, input
    addi t0, t0, 7             # 跳過前 7 個排列字元，指到第 8 個字元
    li   t1, 0                 # t1 = orient，從 0 開始
    li   t2, 6                 # t2 = 還要讀 6 個

loop:
    lbu  t3, 0(t0)             # 讀 1 個字元（ASCII 碼）
    addi t3, t3, -49           # '1' 的 ASCII 是 49，減掉後變成 0、1、2
    slli t4, t1, 1             # t4 = orient << 1（也就是 ×2）
    add  t1, t4, t1            # orient = ×2 + 自己 = ×3
    add  t1, t1, t3            # 再加上這次的數字
    addi t0, t0, 1             # 位址 +1，指到下一個字元
    addi t2, t2, -1            # 計數器 -1
    bnez t2, loop              # 不是 0 就跳回去

    mv   a0, t1                # 印整數要放在 a0
    li   a7, 1                 # ecall 1 = 印整數
    ecall
    li   a7, 10                # ecall 10 = 結束程式
    ecall