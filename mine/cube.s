.data
str:    .string "12345672311111"     
.text
main:
    la   t0, str
    lbu  a0, 7(t0)    
    lbu  a1, 8(t0)             
    addi a0, a0, -49
    addi a1, a1, -49
    slli a2, a0, 1
    add  a2, a2, a0
    add  a0, a2, a1
    li   a7, 1
    ecall