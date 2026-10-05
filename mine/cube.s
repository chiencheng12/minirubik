.data
str:    .string "12345672311111"     
.text
main:
    la   t0, str
    lbu  a0, 8(t0)    
    lbu  a1, 9(t0)             
    li   a7, 1
    slli a2, a0, 1
    addi a2, a2, 1
    addi a0, a2, a1
    ecall