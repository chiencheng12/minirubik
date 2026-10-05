.data
str:    .string "21345671111111"     
.text
main:
    la   t0, str                   

loop:
    lbu  a0, 0(t0)                 # 讀 1 個 byte，放進哪個暫存器？
    beqz a0, done                  # 檢查的是哪個暫存器？
    li   a7, 11                   # 印字元的 ecall 編號
    ecall
    addi t0, t0, 1            # 位址要往前移多少？
    j    loop

done:
    li   a7, 10                 # 結束程式 的 ecall 編號
    ecall