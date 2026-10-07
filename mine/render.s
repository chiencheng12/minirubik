.data
cubie_at: .zero 8                      # 位置 0..7 上放的是哪個角塊（位置 0 是固定的那一塊）
twist_at: .zero 8                      # 位置 0..7 上那個角塊的扭轉 0..2
tmp_c:    .zero 8                      # 轉動時暫存用
tmp_t:    .zero 8
net_xy:
    .byte 9, 3,  4, 7,  9, 7
    .byte 13, 3,  13, 7,  18, 7
    .byte 13, 14,  18, 10,  13, 10
    .byte 9, 14,  9, 10,  4, 10
    .byte 13, 0,  22, 7,  27, 7
    .byte 13, 17,  27, 10,  22, 10
    .byte 9, 17,  0, 10,  31, 10
    .byte 9, 0,  31, 7,  0, 7
home_face:
    .byte 0, 5, 2,  0, 2, 4,  1, 4, 2,  1, 2, 5
    .byte 0, 4, 3,  1, 3, 4,  1, 5, 3,  0, 3, 5
q_source:                              # 轉一面之後，位置 p 的新角塊來自哪個位置
    .byte 0, 2, 5, 3, 1, 4, 6, 7   # R
    .byte 0, 1, 2, 3, 5, 6, 7, 4   # B
    .byte 0, 1, 3, 6, 4, 2, 5, 7   # D
q_twist:                               # 轉一面時，位置 p 的扭轉要加多少
    .byte 0, 1, 2, 0, 2, 1, 0, 0   # R
    .byte 0, 0, 0, 0, 1, 2, 1, 2   # B
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # D
.align 2
face_rgb:
    .word 0xFFFFFF, 0xFFD500, 0x009B48, 0x0046AD, 0xB71234, 0xFF5800

.text
.equ DELAY, 500000                     # 每一格畫面之間的等待（單週期約 0.8 秒）

# animate：先畫打亂的方塊，再照著解法一步一步轉並重畫（s6 = path，s11 = 解的長度）
animate:
    addi sp, sp, -16
    sw   ra, 0(sp)
    sw   s1, 4(sp)
    sw   s2, 8(sp)
    sw   s3, 12(sp)
    jal  ra, load_state
    jal  ra, render
    jal  ra, delay
    li   s1, 0                         # s1 = 第幾步
move_loop:
    beq  s1, s11, anim_done
    add  t0, s6, s1
    lbu  t0, 0(t0)                     # t0 = 這一步的走法編號 m
    la   t1, move_face
    add  t1, t1, t0
    lbu  s2, 0(t1)                     # s2 = 面
    la   t1, move_turn
    add  t1, t1, t0
    lbu  s3, 0(t1)                     # s3 = 要轉幾次
turn_again:
    mv   a0, s2
    jal  ra, quarter_turn
    addi s3, s3, -1
    bnez s3, turn_again
    jal  ra, render                    # 每一步轉完就重畫
    jal  ra, delay
    addi s1, s1, 1
    j    move_loop
anim_done:
    lw   ra, 0(sp)
    lw   s1, 4(sp)
    lw   s2, 8(sp)
    lw   s3, 12(sp)
    addi sp, sp, 16
    ret

# load_state：把輸入字串拆成 cubie_at / twist_at
load_state:
    la   t0, input
    la   t1, cubie_at
    la   t2, twist_at
    li   t3, 7
fill_loop:
    lbu  t4, 0(t0)
    addi t4, t4, -48                   # '1'..'7' 變成角塊編號 1..7
    sb   t4, 1(t1)
    lbu  t5, 7(t0)
    addi t5, t5, -49                   # '1'..'3' 變成扭轉 0..2
    sb   t5, 1(t2)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, -1
    bnez t3, fill_loop
    ret

# quarter_turn：a0 = 面（0 R、1 B、2 D），把 cubie_at / twist_at 轉 90 度
quarter_turn:
    la   t0, cubie_at                  # 先把兩個陣列複製一份
    la   t1, tmp_c
    la   t2, twist_at
    la   t3, tmp_t
    li   t4, 8
qt_copy:
    lbu  t5, 0(t0)
    sb   t5, 0(t1)
    lbu  t5, 0(t2)
    sb   t5, 0(t3)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, 1
    addi t4, t4, -1
    bnez t4, qt_copy
    slli t0, a0, 3                     # 面 × 8（每個面的表有 8 格）
    la   t1, q_source
    add  t1, t1, t0
    la   t2, q_twist
    add  t2, t2, t0
    la   t3, cubie_at
    la   t4, twist_at
    li   a1, 0                         # a1 = 位置
qt_loop:
    lbu  t5, 0(t1)                     # t5 = 這個位置的新內容來自哪個位置
    la   t6, tmp_c
    add  t6, t6, t5
    lbu  a2, 0(t6)
    sb   a2, 0(t3)                     # 新角塊 = 舊的那個位置的角塊
    la   t6, tmp_t
    add  t6, t6, t5
    lbu  a2, 0(t6)
    lbu  a3, 0(t2)
    add  a2, a2, a3                    # 新扭轉 = 舊扭轉 + 轉動加的值
    li   a3, 3
    blt  a2, a3, qt_ok
    addi a2, a2, -3                    # 超過 2 就減 3（mod 3）
qt_ok:
    sb   a2, 0(t4)
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, 1
    addi t4, t4, 1
    addi a1, a1, 1
    li   t5, 8
    blt  a1, t5, qt_loop
    ret

# delay：空迴圈，讓每一格畫面停一下
delay:
    li   t0, DELAY
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    ret

# draw_sticker：a0 = x，a1 = y，a2 = RGB，畫 4 x 3 顆燈
draw_sticker:
    slli t0, a0, 2
    slli t1, a1, 7
    slli t2, a1, 3
    slli t3, a1, 2
    add  t0, t0, t1
    add  t0, t0, t2
    add  t0, t0, t3
    li   t4, LED_MATRIX_0_BASE
    add  t0, t0, t4
    li   t5, 3
d_row:
    sw   a2, 0(t0)
    sw   a2, 4(t0)
    sw   a2, 8(t0)
    sw   a2, 12(t0)
    addi t0, t0, 140
    addi t5, t5, -1
    bnez t5, d_row
    ret

# render：把 cubie_at / twist_at 描述的方塊畫在 LED 上
render:
    addi sp, sp, -28
    sw   ra, 0(sp)
    sw   s0, 4(sp)
    sw   s1, 8(sp)
    sw   s2, 12(sp)
    sw   s3, 16(sp)
    sw   s4, 20(sp)
    la   s0, net_xy
    li   s1, 0
pos_loop:
    la   t0, cubie_at
    add  t0, t0, s1
    lbu  t1, 0(t0)
    la   t0, twist_at
    add  t0, t0, s1
    lbu  s4, 0(t0)
    slli t2, t1, 1
    add  t2, t2, t1
    la   t0, home_face
    add  s2, t0, t2
    li   s3, 0
slot_loop:
    sub  t3, s3, s4
    bgez t3, no_wrap
    addi t3, t3, 3
no_wrap:
    add  t3, s2, t3
    lbu  t3, 0(t3)
    slli t3, t3, 2
    la   t4, face_rgb
    add  t3, t4, t3
    lw   a2, 0(t3)
    lbu  a0, 0(s0)
    lbu  a1, 1(s0)
    jal  ra, draw_sticker
    addi s0, s0, 2
    addi s3, s3, 1
    li   t0, 3
    blt  s3, t0, slot_loop
    addi s1, s1, 1
    li   t0, 8
    blt  s1, t0, pos_loop
    lw   ra, 0(sp)
    lw   s0, 4(sp)
    lw   s1, 8(sp)
    lw   s2, 12(sp)
    lw   s3, 16(sp)
    lw   s4, 20(sp)
    addi sp, sp, 28
    ret
