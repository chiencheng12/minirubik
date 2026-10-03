# Stage 1 量測 B（記憶體組）：依序寫入 K 個「不同」的 guest byte
.equ K, 1000000          # 寫入的 byte 數（measure.sh 會改這個值）
    li   t0, 0x10000000  # data 區起點
    li   t1, K
    li   t2, 1
loop:
    sb   t2, 0(t0)       # 每次寫到新位址
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, loop
    li   a7, 10
    ecall
