# Stage 1 量測 A：模擬速度（每秒 retired 幾條指令）
# 純計算迴圈，每圈 2 條指令，不碰記憶體
.equ N, 1000000          # 迴圈次數（measure.sh 會改這個值）
    li   t0, N
loop:
    addi t0, t0, -1
    bnez t0, loop
    li   a7, 10          # exit
    ecall
