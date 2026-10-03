# Stage 1 量測 B（對照組）：指令數跟 mem.s 一樣，但永遠寫「同一個」位址
.equ K, 1000000
    li   t0, 0x10000000
    li   t1, K
    li   t2, 1
loop:
    sb   t2, 0(t0)       # 永遠寫同一格
    addi t3, t3, 1       # 佔位，讓指令數跟 mem.s 相同
    addi t1, t1, -1
    bnez t1, loop
    li   a7, 10
    ecall
