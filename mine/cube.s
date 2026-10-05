.data
str:    .string "12345672311111"     
.text
main:
    la   t0, str
    lbu  a0, 7(t0)                 
    li   a7, 1
    addi a0, a0, -49
    ecall