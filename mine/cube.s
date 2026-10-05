.data
input:  .asciz "21345671111111"
where:  .zero 8                    # 預留 8 byte，存 where[0..6]

.text
main:
    la   t0, input                 # t0 = 輸入字元的位址
    la   t1, where                 # t1 = where 表的起點
    li   t2, 0                     # t2 = i（位置編號）
    li   t3, 7                     # t3 = 迴圈上限

loop:
    lbu  t4, 0(t0)                 # 讀第 i 個字元
    addi t4, t4, -49               # '1'~'7' 變成 cubie 編號 0~6
    add  t5, t1, t4                # t5 = where 起點 + cubie = where[cubie] 的位址
    sb   t2, 0(t5)                 # where[cubie] = i
    addi t2, t2, 1                 # i++
    addi t0, t0, 1                 # 輸入位址 +1
    bne  t2, t3, loop              # i 還沒到 7 就繼續

    lbu  a0, 0(t1)                 # a0 = where[0]
    li   a7, 1                     # 印整數
    ecall
    li   a7, 10                    # 結束
    ecall