############################################################
# physics.asm
# Sistema de f�sica y detecci�n de colisiones
# Mario Platformer - MARS 4.5
# Fixed-point arithmetic (scale 100)
############################################################

.include "constants.asm"

############################################################
# FUNCI�N: apply_gravity
# Aplica gravedad a Mario cada frame
# Modifica: mario_velocity_y
############################################################
.text
.globl apply_gravity
apply_gravity:
    # Cargar velocidad vertical actual
    lw $t0, mario_velocity_y
    
    # Aplicar gravedad: velocity_y += GRAVITY
    li $t1, GRAVITY
    add $t0, $t0, $t1
    
    # Limitar velocidad de ca�da m�xima
    li $t1, MAX_FALL_SPEED
    blt $t0, $t1, clamp_fall_speed
    j gravity_done
    
clamp_fall_speed:
    li $t0, MAX_FALL_SPEED
    
gravity_done:
    # Guardar nueva velocidad
    sw $t0, mario_velocity_y
    jr $ra

############################################################
# FUNCI�N: update_mario_position
# Actualiza posici�n de Mario basado en velocidad
# Aplica: position += velocity
############################################################
.text
.globl update_mario_position
update_mario_position:
    # === Actualizar posici�n X ===
    lw $t0, mario_x
    lw $t1, mario_velocity_x
    add $t0, $t0, $t1
    sw $t0, mario_x
    
    # === Actualizar posici�n Y ===
    lw $t0, mario_y
    lw $t1, mario_velocity_y
    add $t0, $t0, $t1
    sw $t0, mario_y
    
    # === Aplicar fricci�n a velocidad horizontal ===
    lw $t0, mario_velocity_x
    
    # Si velocidad es positiva
    bgtz $t0, friction_positive
    
    # Si velocidad es negativa
    bltz $t0, friction_negative
    
    # Si es cero, no hacer nada
    j friction_done
    
friction_positive:
    # Reducir velocidad gradualmente
    subi $t0, $t0, 20       # Reducir por 0.20
    bltz $t0, friction_zero # Si pasa de 0, poner en 0
    sw $t0, mario_velocity_x
    j friction_done
    
friction_negative:
    # Incrementar velocidad (acercar a 0)
    addi $t0, $t0, 20
    bgtz $t0, friction_zero
    sw $t0, mario_velocity_x
    j friction_done
    
friction_zero:
    sw $zero, mario_velocity_x
    
friction_done:
    jr $ra

############################################################
# FUNCI�N: check_collision_aabb
# Detecci�n de colisi�n AABB (Axis-Aligned Bounding Box)
# Par�metros:
#   $a0 = x1 (fixed-point)
#   $a1 = y1 (fixed-point)
#   $a2 = width1
#   $a3 = height1
#   Stack: x2, y2, width2, height2
# Retorna:
#   $v0 = 1 si hay colisi�n, 0 si no
############################################################
.text
.globl check_collision_aabb
check_collision_aabb:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Cargar par�metros adicionales del stack
    lw $t4, 4($sp)          # x2
    lw $t5, 8($sp)          # y2
    lw $t6, 12($sp)         # width2
    lw $t7, 16($sp)         # height2
    
    # Convertir fixed-point a enteros para comparaci�n
    li $t8, FIXED_SCALE
    
    # Calcular bordes de rect1
    div $a0, $t8
    mflo $s0                # x1
    div $a1, $t8
    mflo $s1                # y1
    add $s2, $s0, $a2       # right1 = x1 + width1
    add $s3, $s1, $a3       # bottom1 = y1 + height1
    
    # Calcular bordes de rect2
    div $t4, $t8
    mflo $t0                # x2
    div $t5, $t8
    mflo $t1                # y2
    add $t2, $t0, $t6       # right2 = x2 + width2
    add $t3, $t1, $t7       # bottom2 = y2 + height2
    
    # Verificar las 4 condiciones de NO colisi�n:
    # 1. rect1.right <= rect2.left
    sle $t8, $s2, $t0
    bnez $t8, no_collision
    
    # 2. rect2.right <= rect1.left
    sle $t8, $t2, $s0
    bnez $t8, no_collision
    
    # 3. rect1.bottom <= rect2.top
    sle $t8, $s3, $t1
    bnez $t8, no_collision
    
    # 4. rect2.bottom <= rect1.top
    sle $t8, $t3, $s1
    bnez $t8, no_collision
    
    # Si ninguna condici�n de NO colisi�n se cumple = HAY colisi�n
    li $v0, 1
    j collision_return
    
no_collision:
    li $v0, 0
    
collision_return:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

############################################################
# FUNCI�N: check_mario_tile_collision
# Verifica colisi�n de Mario con un tile espec�fico
# Par�metros:
#   $a0 = tile_x (en unidades de tile)
#   $a1 = tile_y (en unidades de tile)
# Retorna:
#   $v0 = 1 si colisiona, 0 si no
############################################################
.text
.globl check_mario_tile_collision
check_mario_tile_collision:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    
    # Convertir posici�n de tile a fixed-point
    li $t0, FIXED_SCALE
    mult $a0, $t0
    mflo $t1                # tile_x en fixed-point
    mult $a1, $t0
    mflo $t2                # tile_y en fixed-point
    
    # Preparar par�metros para AABB
    lw $a0, mario_x         # x1
    lw $a1, mario_y         # y1
    li $a2, MARIO_WIDTH     # width1
    li $a3, MARIO_HEIGHT    # height1
    
    # Par�metros en stack
    addi $sp, $sp, -16
    sw $t1, 0($sp)          # x2
    sw $t2, 4($sp)          # y2
    li $t0, TILE_SIZE
    sw $t0, 8($sp)          # width2
    sw $t0, 12($sp)         # height2
    
    jal check_collision_aabb
    
    addi $sp, $sp, 16
    
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

############################################################
# FUNCI�N: resolve_collision_vertical
# Resuelve colisi�n vertical (suelo/techo)
# Par�metros:
#   $a0 = tile_y (unidades de tile)
#   $a1 = collision_from_below (1 = desde abajo, 0 = desde arriba)
############################################################
.text
.globl resolve_collision_vertical
resolve_collision_vertical:
    beqz $a1, collision_from_above
    
    # Colisi�n desde arriba (aterrizar en suelo)
    # Posicionar Mario justo encima del tile
    li $t0, FIXED_SCALE
    mult $a0, $t0
    mflo $t1                # tile_y en fixed-point
    
    # mario_y = tile_y * 100 - MARIO_HEIGHT * 100
    li $t2, MARIO_HEIGHT
    mult $t2, $t0
    mflo $t2
    sub $t1, $t1, $t2
    
    sw $t1, mario_y
    
    # Resetear velocidad vertical
    sw $zero, mario_velocity_y
    
    # Marcar que est� en el suelo
    li $t0, 1
    sw $t0, mario_on_ground
    
    jr $ra
    
collision_from_above:
    # Colisi�n de cabeza con techo
    # Posicionar Mario justo debajo del tile
    li $t0, FIXED_SCALE
    mult $a0, $t0
    mflo $t1
    
    # mario_y = (tile_y + 1) * 100
    addi $t1, $t1, 100
    sw $t1, mario_y
    
    # Cancelar velocidad ascendente
    sw $zero, mario_velocity_y
    
    jr $ra

############################################################
# FUNCI�N: resolve_collision_horizontal
# Resuelve colisi�n horizontal (paredes)
# Par�metros:
#   $a0 = tile_x (unidades de tile)
#   $a1 = collision_from_left (1 = desde izquierda, 0 = desde derecha)
############################################################
.text
.globl resolve_collision_horizontal
resolve_collision_horizontal:
    beqz $a1, collision_from_right
    
    # Colisi�n desde la izquierda (pared a la derecha)
    li $t0, FIXED_SCALE
    mult $a0, $t0
    mflo $t1
    
    # mario_x = tile_x * 100 - MARIO_WIDTH * 100
    li $t2, MARIO_WIDTH
    mult $t2, $t0
    mflo $t2
    sub $t1, $t1, $t2
    
    sw $t1, mario_x
    
    # Cancelar velocidad horizontal
    sw $zero, mario_velocity_x
    
    jr $ra
    
collision_from_right:
    # Colisi�n desde la derecha (pared a la izquierda)
    li $t0, FIXED_SCALE
    mult $a0, $t0
    mflo $t1
    
    # mario_x = (tile_x + 1) * 100
    addi $t1, $t1, 100
    sw $t1, mario_x
    
    # Cancelar velocidad horizontal
    sw $zero, mario_velocity_x
    
    jr $ra

############################################################
# FUNCI�N: check_ground_below
# Verifica si hay suelo justo debajo de Mario
# Retorna: $v0 = 1 si hay suelo, 0 si no
############################################################
.text
.globl check_ground_below
check_ground_below:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    
    # Calcular tile debajo de Mario
    lw $t0, mario_y
    li $t1, FIXED_SCALE
    div $t0, $t1
    mflo $t0                # mario_y en tiles
    
    addi $t0, $t0, 1        # tile_y + 1 (debajo)
    
    # Calcular tile X de Mario
    lw $t1, mario_x
    li $t2, FIXED_SCALE
    div $t1, $t2
    mflo $t1                # mario_x en tiles
    
    # Verificar tile en esa posici�n
    move $a0, $t1
    move $a1, $t0
    jal get_tile_type
    
    # Si es tile s�lido (TILE_GROUND o TILE_BRICK)
    li $t0, TILE_GROUND
    beq $v0, $t0, ground_found
    li $t0, TILE_BRICK
    beq $v0, $t0, ground_found
    
    # No hay suelo
    li $v0, 0
    j check_ground_done
    
ground_found:
    li $v0, 1
    
check_ground_done:
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

############################################################
# FUNCI�N: get_tile_type
# Obtiene el tipo de tile en una posici�n
# Par�metros:
#   $a0 = tile_x
#   $a1 = tile_y
# Retorna:
#   $v0 = tipo de tile (TILE_AIR, TILE_GROUND, etc)
############################################################
.text
.globl get_tile_type
get_tile_type:
    # Verificar l�mites
    bltz $a0, tile_out_of_bounds
    li $t0, MAP_WIDTH
    bge $a0, $t0, tile_out_of_bounds
    bltz $a1, tile_out_of_bounds
    li $t0, MAP_HEIGHT
    bge $a1, $t0, tile_out_of_bounds
    
    # Calcular offset: (y * MAP_WIDTH + x) * 4
    lw $t0, map_data
    li $t1, MAP_WIDTH
    mult $a1, $t1
    mflo $t2
    add $t2, $t2, $a0
    sll $t2, $t2, 2         # * 4
    add $t2, $t0, $t2
    
    # Cargar tipo
    lw $v0, 0($t2)
    jr $ra
    
tile_out_of_bounds:
    li $v0, TILE_AIR
    jr $ra

############################################################
# FUNCI�N: set_tile_type
# Establece el tipo de tile en una posici�n
# Par�metros:
#   $a0 = tile_x
#   $a1 = tile_y
#   $a2 = tipo de tile
############################################################
.text
.globl set_tile_type
set_tile_type:
    # Verificar l�mites
    bltz $a0, set_tile_return
    li $t0, MAP_WIDTH
    bge $a0, $t0, set_tile_return
    bltz $a1, set_tile_return
    li $t0, MAP_HEIGHT
    bge $a1, $t0, set_tile_return
    
    # Calcular offset
    lw $t0, map_data
    li $t1, MAP_WIDTH
    mult $a1, $t1
    mflo $t2
    add $t2, $t2, $a0
    sll $t2, $t2, 2
    add $t2, $t0, $t2
    
    # Guardar tipo
    sw $a2, 0($t2)
    
set_tile_return:
    jr $ra

############################################################
# FUNCI�N: check_mario_map_collisions
# Verifica todas las colisiones de Mario con el mapa
# Detecta y resuelve colisiones en X e Y por separado
############################################################
.text
.globl check_mario_map_collisions
check_mario_map_collisions:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    
    # Resetear flag de suelo
    sw $zero, mario_on_ground
    
    # === COLISIONES HORIZONTALES ===
    # Calcular tiles que ocupa Mario
    lw $t0, mario_x
    li $t1, FIXED_SCALE
    div $t0, $t1
    mflo $s0                # tile_x
    
    lw $t0, mario_y
    div $t0, $t1
    mflo $s1                # tile_y
    
    # Verificar tiles alrededor (3x3)
    addi $t0, $s1, -1       # Arriba
    move $t1, $s0
    
check_h_loop_y:
    addi $t2, $s1, 1
    bgt $t0, $t2, check_v_collisions
    
    addi $t1, $s0, -1       # Izquierda
check_h_loop_x:
    addi $t2, $s0, 1
    bgt $t1, $t2, check_h_next_y
    
    # Verificar tipo de tile
    move $a0, $t1
    move $a1, $t0
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    
    jal get_tile_type
    move $t3, $v0
    
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    
    # Si es tile s�lido, verificar colisi�n
    li $t4, TILE_GROUND
    beq $t3, $t4, check_h_solid
    li $t4, TILE_BRICK
    beq $t3, $t4, check_h_solid
    j check_h_skip
    
check_h_solid:
    move $a0, $t1
    move $a1, $t0
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    
    jal check_mario_tile_collision
    
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    
    beqz $v0, check_h_skip
    
    # HAY COLISI�N - determinar direcci�n
    lw $t5, mario_velocity_x
    bgtz $t5, h_from_left
    
    # Desde derecha
    move $a0, $t1
    li $a1, 0
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    jal resolve_collision_horizontal
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    j check_h_skip
    
h_from_left:
    move $a0, $t1
    li $a1, 1
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    jal resolve_collision_horizontal
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    
check_h_skip:
    addi $t1, $t1, 1
    j check_h_loop_x
    
check_h_next_y:
    addi $t0, $t0, 1
    j check_h_loop_y
    
    # === COLISIONES VERTICALES ===
check_v_collisions:
    # Recalcular posici�n despu�s de resolver horizontales
    lw $t0, mario_x
    li $t1, FIXED_SCALE
    div $t0, $t1
    mflo $s0
    
    lw $t0, mario_y
    div $t0, $t1
    mflo $s1
    
    addi $t0, $s1, -1
    move $t1, $s0
    
check_v_loop_y:
    addi $t2, $s1, 1
    bgt $t0, $t2, collisions_done
    
    addi $t1, $s0, -1
check_v_loop_x:
    addi $t2, $s0, 1
    bgt $t1, $t2, check_v_next_y
    
    move $a0, $t1
    move $a1, $t0
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    jal get_tile_type
    move $t3, $v0
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    
    li $t4, TILE_GROUND
    beq $t3, $t4, check_v_solid
    li $t4, TILE_BRICK
    beq $t3, $t4, check_v_solid
    j check_v_skip
    
check_v_solid:
    move $a0, $t1
    move $a1, $t0
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    jal check_mario_tile_collision
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    
    beqz $v0, check_v_skip
    
    # HAY COLISI�N VERTICAL
    lw $t5, mario_velocity_y
    bltz $t5, v_from_below
    
    # Desde arriba (aterrizar)
    move $a0, $t0
    li $a1, 1
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    jal resolve_collision_vertical
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    j check_v_skip
    
v_from_below:
    move $a0, $t0
    li $a1, 0
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    jal resolve_collision_vertical
    lw $t1, 4($sp)
    lw $t0, 0($sp)
    addi $sp, $sp, 8
    
check_v_skip:
    addi $t1, $t1, 1
    j check_v_loop_x
    
check_v_next_y:
    addi $t0, $t0, 1
    j check_v_loop_y
    
collisions_done:
    lw $s1, 8($sp)
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    jr $ra

############################################################
# Fin de physics.asm
############################################################