.data
bitmap:   .word 0x10040000

# Colores
rojo:     .word 0x00FF0000
verde:    .word 0x0000FF00
amarillo: .word 0x00FFFF00
cafe:     .word 0x00AA5500
negro:    .word 0x00000000

# Jugador
px:  .word 10
py:  .word 40
pvy: .word 0

# Plataformas
plats:
    .word 0, 56, 64, 4
    .word 10, 40, 20, 3
    .word 35, 30, 15, 3
    .word -1, -1, -1, -1

# Monedas
coins:
    .word 20, 36, 1
    .word 40, 26, 1
    .word -1, -1, -1

# Enemigos
enemies:
    .word 45, 48, -1, 1
    .word 15, 36, 1, 1
    .word -1, -1, -1, -1

# Estado
pts:   .word 0
lives: .word 3

msg1: .asciiz "Puntos: "
msg2: .asciiz " Vidas: "
msgWin: .asciiz "\n¡GANASTE!\n"
msgOver: .asciiz "\nGAME OVER\n"

.text
.globl main

main:
    jal init_screen
    jal draw_all
    jal update_hud

main_loop:
    li $v0, 12
    syscall
    
    beq $v0, 119, do_jump
    beq $v0, 97, do_left
    beq $v0, 100, do_right
    beq $v0, 113, do_quit
    
    jal physics_step
    j main_loop

do_jump:
    jal is_grounded
    beqz $v0, main_loop
    li $t0, -10
    sw $t0, pvy
    jal physics_step
    j main_loop

do_left:
    lw $t0, px
    subi $t0, $t0, 2
    bge $t0, 0, store_left
    li $t0, 0
store_left:
    sw $t0, px
    jal physics_step
    j main_loop

do_right:
    lw $t0, px
    addi $t0, $t0, 2
    ble $t0, 58, store_right
    li $t0, 58
store_right:
    sw $t0, px
    jal physics_step
    j main_loop

do_quit:
    li $v0, 10
    syscall

physics_step:
    lw $t0, pvy
    addi $t0, $t0, 1
    sw $t0, pvy

    lw $t1, py
    add $t2, $t1, $t0
    sw $t2, py

    li $t3, 50
    ble $t2, $t3, check_platforms
    sw $t3, py
    sw $zero, pvy
    jal draw_all
    jr $ra

check_platforms:
    lw $t4, pvy
    blez $t4, update_rest

    la $t5, plats
platform_loop:
    lw $t6, 0($t5)
    beq $t6, -1, update_rest
    lw $t7, 4($t5)
    lw $t8, 8($t5)
    lw $t9, 12($t5)

    lw $t0, py
    addi $t1, $t0, 6
    blt $t1, $t7, next_platform

    sub $t2, $t1, $t7
    bgt $t2, 3, next_platform

    lw $t3, px
    addi $t4, $t3, 6
    blt $t4, $t6, next_platform
    add $t0, $t6, $t8
    bgt $t3, $t0, next_platform

    sub $t1, $t7, 6
    sw $t1, py
    sw $zero, pvy
    jal draw_all
    jr $ra

next_platform:
    addi $t5, $t5, 16
    j platform_loop

update_rest:
    jal update_enemies
    jal check_collisions
    jr $ra

update_enemies:
    la $t0, enemies
enemy_loop:
    lw $t1, 0($t0)
    beq $t1, -1, enemy_done
    lw $t2, 12($t0)
    beqz $t2, next_enemy
    lw $t3, 8($t0)
    add $t1, $t1, $t3
    sw $t1, 0($t0)

    ble $t1, 2, flip_enemy
    bge $t1, 58, flip_enemy
    j next_enemy

flip_enemy:
    neg $t3, $t3
    sw $t3, 8($t0)

next_enemy:
    addi $t0, $t0, 16
    j enemy_loop

enemy_done:
    jr $ra

check_collisions:
    la $t0, coins
coin_loop:
    lw $t1, 0($t0)
    beq $t1, -1, enemy_col
    lw $t2, 8($t0)
    beqz $t2, next_coin
    lw $t3, 4($t0)
    lw $t4, px
    lw $t5, py

    sub $t6, $t4, $t1
    abs $t6, $t6
    bgt $t6, 6, next_coin

    sub $t6, $t5, $t3
    abs $t6, $t6
    bgt $t6, 6, next_coin

    sw $zero, 8($t0)
    lw $t7, pts
    addi $t7, $t7, 10
    sw $t7, pts
    jal draw_all
    jal update_hud
    jal check_win

next_coin:
    addi $t0, $t0, 12
    j coin_loop

enemy_col:
    la $t0, enemies
enemy_col_loop:
    lw $t1, 0($t0)
    beq $t1, -1, redraw
    lw $t2, 12($t0)
    beqz $t2, next_enemy_col
    lw $t3, 4($t0)
    lw $t4, px
    lw $t5, py

    sub $t6, $t4, $t1
    abs $t6, $t6
    bgt $t6, 6, next_enemy_col

    sub $t6, $t5, $t3
    abs $t6, $t6
    bgt $t6, 6, next_enemy_col

    sub $t7, $t5, $t3
    blt $t7, -2, kill_enemy

    lw $t8, lives
    subi $t8, $t8, 1
    sw $t8, lives
    li $t9, 10
    sw $t9, px
    li $t9, 40
    sw $t9, py
    sw $zero, pvy
    jal draw_all
    jal update_hud
    lw $t9, lives
    blez $t9, game_over
    j next_enemy_col

kill_enemy:
    sw $zero, 12($t0)
    li $t8, -6
    sw $t8, pvy
    lw $t9, pts
    addi $t9, $t9, 50
    sw $t9, pts
    jal draw_all
    jal update_hud

next_enemy_col:
    addi $t0, $t0, 16
    j enemy_col_loop

redraw:
    jal draw_all
    li $a0, 30
    li $v0, 32
    syscall
    jr $ra

is_grounded:
    lw $t0, py
    li $t1, 50
    bge $t0, $t1, grounded

    la $t2, plats
ground_check:
    lw $t3, 0($t2)
    beq $t3, -1, not_grounded
    lw $t4, 4($t2)
    lw $t0, py
    addi $t0, $t0, 6
    bne $t0, $t4, next_ground
    
    lw $t5, px
    addi $t6, $t5, 6
    blt $t6, $t3, next_ground
    lw $t7, 8($t2)
    add $t8, $t3, $t7
    bgt $t5, $t8, next_ground
    j grounded
    
next_ground:
    addi $t2, $t2, 16
    j ground_check

grounded:
    li $v0, 1
    jr $ra
not_grounded:
    li $v0, 0
    jr $ra

init_screen:
    lw $t0, bitmap
    lw $t1, negro
    li $t2, 16384
clear_loop:
    sw $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    bnez $t2, clear_loop
    jr $ra

draw_all:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal init_screen
    
    # Plataformas
    la $t0, plats
draw_platforms:
    lw $a0, 0($t0)
    beq $a0, -1, draw_coins
    lw $a1, 4($t0)
    lw $a2, 8($t0)
    lw $a3, 12($t0)
    lw $t1, verde
    jal draw_rect
    addi $t0, $t0, 16
    j draw_platforms

draw_coins:
    la $t0, coins
draw_coins_loop:
    lw $a0, 0($t0)
    beq $a0, -1, draw_enemies
    lw $t1, 8($t0)
    beqz $t1, next_coin_draw
    lw $a1, 4($t0)
    lw $a2, amarillo
    jal draw_box
next_coin_draw:
    addi $t0, $t0, 12
    j draw_coins_loop

draw_enemies:
    la $t0, enemies
draw_enemies_loop:
    lw $a0, 0($t0)
    beq $a0, -1, draw_player
    lw $t1, 12($t0)
    beqz $t1, next_enemy_draw
    lw $a1, 4($t0)
    lw $a2, cafe
    jal draw_box
next_enemy_draw:
    addi $t0, $t0, 16
    j draw_enemies_loop

draw_player:
    lw $a0, px
    lw $a1, py
    lw $a2, rojo
    jal draw_box

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_rect:
    move $t2, $a1
    add $t3, $a1, $a3
rect_y:
    bge $t2, $t3, rect_done
    move $t4, $a0
    add $t5, $a0, $a2
rect_x:
    bge $t4, $t5, rect_x_done
    move $a0, $t4
    move $a1, $t2
    move $a2, $t1
    jal draw_pixel
    addi $t4, $t4, 1
    j rect_x
rect_x_done:
    addi $t2, $t2, 1
    j rect_y
rect_done:
    jr $ra

draw_box:
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2

    li $s3, 0
box_y:
    bge $s3, 6, box_done
    li $s4, 0
box_x:
    bge $s4, 6, box_x_done
    add $a0, $s0, $s4
    add $a1, $s1, $s3
    move $a2, $s2
    jal draw_pixel
    addi $s4, $s4, 1
    j box_x
box_x_done:
    addi $s3, $s3, 1
    j box_y
box_done:
    jr $ra

draw_pixel:
    # Coordenadas lógicas: 0-63
    # Escalar a físicas: multiplicar por 8
    sll $t0, $a0, 3   # x * 8
    sll $t1, $a1, 3   # y * 8
    
    # Dibujar bloque 8x8
    li $t2, 0
block_y:
    bge $t2, 8, block_done
    li $t3, 0
block_x:
    bge $t3, 8, block_x_done
    
    add $t4, $t0, $t3  # x_final
    add $t5, $t1, $t2  # y_final
    
    # Verificar límites
    bltz $t4, skip_pixel
    bltz $t5, skip_pixel
    bge $t4, 512, skip_pixel
    bge $t5, 512, skip_pixel
    
    # Calcular dirección
    lw $t6, bitmap
    sll $t7, $t5, 9    # y * 512
    add $t7, $t7, $t4  # y*512 + x
    sll $t7, $t7, 2    # *4
    add $t6, $t6, $t7
    sw $a2, 0($t6)
    
skip_pixel:
    addi $t3, $t3, 1
    j block_x
    
block_x_done:
    addi $t2, $t2, 1
    j block_y
    
block_done:
    jr $ra

update_hud:
    li $v0, 4
    la $a0, msg1
    syscall

    li $v0, 1
    lw $a0, pts
    syscall

    li $v0, 4
    la $a0, msg2
    syscall

    li $v0, 1
    lw $a0, lives
    syscall

    li $v0, 11
    li $a0, 10
    syscall
    jr $ra

check_win:
    la $t0, coins
check_win_loop:
    lw $t1, 0($t0)
    beq $t1, -1, win
    lw $t2, 8($t0)
    bnez $t2, no_win
    addi $t0, $t0, 12
    j check_win_loop

win:
    li $v0, 4
    la $a0, msgWin
    syscall
    j do_quit

no_win:
    jr $ra

game_over:
    li $v0, 4
    la $a0, msgOver
    syscall
    j do_quit