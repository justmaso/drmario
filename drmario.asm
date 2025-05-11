################# CSC258 Assembly Final Project ###################
# This file contains my implementation of Dr Mario.

# Student: Mason Law
# I assert that the code submitted here is entirely my own 
# creation, and will indicate otherwise when it is not.

######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    64
# - Display height in pixels:   64
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data
# Immutable Data-----------------------------------------------------------
DISPLAY:          .word 0x10008000  # the address of the bitmap display
DISPLAY_COPY:     .word 0x10009000  # the address of the copy of the bitmap display
KEYBOARD:         .word 0xffff0000  # the address of the keyboard
C1:               .word 0xFF7F7F    # light red
C2:               .word 0x98FF98    # light green
C3:               .word 0x7FBFFF    # jordy blue
WHITE:            .word 0xffffff    # white
BLACK:            .word 0x000000    # black
ACTIVE_CAPSULE:   .word 16 3 16 4 0
Q1_CAPSULE:       .word 20 1 21 2 0
Q2_CAPSULE:       .word 23 1 24 2 0
Q3_CAPSULE:       .word 26 1 27 2 0
Q4_CAPSULE:       .word 29 1 30 2 0

# Mutable Data-------------------------------------------------------------
TIMER:            .word 3
CAPSULE:          .word 16 3 16 4 0
ELIMINATIONS:     .word 0
VIRUS_LOCATIONS:  .word 0 0 0 0 0 0 0 0

# Code-------------------------------------------------------------
.text
.globl main

# pre-load sounds
jal load_rotate_sound
jal load_move_left_sound
jal load_move_down_sound
jal load_move_right_sound
jal load_pause_sound
jal load_game_over_sound
jal load_four_in_a_row_sound
jal load_win_sound

# main initializes the game
main:
    # reset eliminations
    la $t0, ELIMINATIONS
    li $t1, 0
    sw $t1, 0($t0)
    
    # resets the virus locations to prevent unecessary drawing redo
    la $t0, VIRUS_LOCATIONS
    sw $zero, 0($t0)
    sw $zero, 4($t0)
    sw $zero, 8($t0)
    sw $zero, 12($t0)
    sw $zero, 16($t0)
    sw $zero, 20($t0)
    sw $zero, 24($t0)
    sw $zero, 28($t0)
    jal reset_active_capsule
    lw $a0, BLACK
    jal clear_screen
    jal draw_bottle
    la $t1, ACTIVE_CAPSULE
    jal draw_capsule
    la $t1, Q1_CAPSULE
    jal draw_capsule
    la $t1, Q2_CAPSULE
    jal draw_capsule
    la $t1, Q3_CAPSULE
    jal draw_capsule
    la $t1, Q4_CAPSULE
    jal draw_capsule
    jal draw_viruses
    
game_loop:
    # checks key presses
    lw $t0, KEYBOARD
    lw $t8, 0($t0)
    beq $t8, 1, keyboard_input
    la $t1, TIMER
    lw $t2, 0($t1)
    beqz $t2, gravity
    j no_gravity_yet

    gravity:
        jal s_pressed
        la $t1, TIMER
        li $t2, 3
        sw $t2, 0($t1)
        j continue
    no_gravity_yet:
        subi $t2, $t2, 1
        sw $t2, 0($t1)
    continue:
    	jal sleep    # sleeps so we're not continuously checking
        j game_loop  # repeat

sleep:
    li $v0, 32
    li $a0, 50
    syscall
    j return

check_four_in_a_row:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, DISPLAY
    lw $a3, WHITE

    jal check_rows
    jal check_columns
    
    # after removing consecutive colours, check eliminations
    lw $t1, ELIMINATIONS
    bne $t1, 4, end_check_four_in_a_row
    jal play_win_sound
    lw $a0, WHITE
    jal clear_screen
    jal draw_peace_mario
    j end_loop
    
    end_check_four_in_a_row:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

check_rows:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a2, 17 # width of the inside of the bottle
    sll $a2, $a2, 2
    # TL 8,6..., BL 8, 28... TR 24, 6... BR, 24,28
    li $t1, 8        # the leftmost column
    li $t2, 28       # the bottom row
    sll $t1, $t1, 2  # offset to get to leftmost column
    sll $t2, $t2, 7  # offset to get to the bottom row
    
    add $t4, $t0, $t1
    add $t4, $t4, $t2
    # now, t4 is the current position in the row

    # first, check the rows
    start_row:
        lw $t6, 0($t4)         # the current colour
        li $a0, 1              # the current count of the colour
        beq $t6, $a3, prev_row # white reached, move up a row
        beqz $t6, new_column   # black reached, move to a new column
        
        # check the next pixels to see if they match
        check_row:
            addi $t4, $t4, 4
            lw $t7, 0($t4)
            beqz $t7, start_row      # colour is black, start at this position
            bne $t7, $t6, start_row  # colours don't match, start at this position
            addi $a0, $a0, 1 # increase count of colour by 1
            beq $a0, 4, erase_consecutive_row
            j check_row
        erase_consecutive_row:            
            la $t8, VIRUS_LOCATIONS
            lw $t9, 0($t8)
            beq $t4, $t9, first_row_virus
            lw $t9, 8($t8)
            beq $t4, $t9, second_row_virus
            lw $t9, 16($t8)
            beq $t4, $t9, third_row_virus
            lw $t9, 24($t8)
            beq $t4, $t9, fourth_row_virus
            j continue_erasing_row

            first_row_virus:
                jal remove_first_virus
                j continue_erasing_row
            second_row_virus:
                jal remove_second_virus
                j continue_erasing_row
            third_row_virus:
                jal remove_third_virus
                j continue_erasing_row
            fourth_row_virus:
                jal remove_fourth_virus
            continue_erasing_row:
                sw $zero, 0($t4)
                addi $t4, $t4, -4
                addi $a0, $a0, -1
                beqz $a0, end_consecutive_row
                j erase_consecutive_row
        end_consecutive_row:    
            addi $sp, $sp, -4
            sw $a0, 0($sp)
            addi $sp, $sp, -4
            sw $a1, 0($sp)
            addi $sp, $sp, -4
            sw $a2, 0($sp)
            addi $sp, $sp, -4
            sw $a3, 0($sp)
            jal play_four_in_a_row_sound  # destroys v0, a0-3
            lw $a3, 0($sp)
            addi $sp, $sp, 4
            lw $a2, 0($sp)
            addi $sp, $sp, 4
            lw $a1, 0($sp)
            addi $sp, $sp, 4
            lw $a0, 0($sp)
            
            # after erasing, do a small delay so the user can see the display before
            sw $a0, 0($sp)
            li $v0, 32
            li $a0, 450
            syscall
            lw $a0, 0($sp)

            sw $a0, 0($sp)
            addi $sp, $sp, -4
            sw $a1, 0($sp)
            addi $sp, $sp, -4
            sw $t1, 0($sp)
            addi $sp, $sp, -4
            sw $t2, 0($sp)
            addi $sp, $sp, -4
            sw $t3, 0($sp)
            addi $sp, $sp, -4
            sw $t4, 0($sp)
            addi $sp, $sp, -4
            sw $t5, 0($sp)
            jal drop_propagate # destroys a0-1, t1-5
            lw $t5, 0($sp)
            addi $sp, $sp, 4
            lw $t4, 0($sp)
            addi $sp, $sp, 4
            lw $t3, 0($sp)
            addi $sp, $sp, 4
            lw $t2, 0($sp)
            addi $sp, $sp, 4
            lw $t1, 0($sp)
            addi $sp, $sp, 4
            lw $a1, 0($sp)
            addi $sp, $sp, 4
            lw $a0, 0($sp)

            # after dropping, do a small delay
            sw $a0, 0($sp)
            li $v0, 32
            li $a0, 800
            syscall
            lw $a0, 0($sp)
            
            # after propagating the drop, check for new formations
            sw $a0, 0($sp)
            addi $sp, $sp, -4
            sw $a1, 0($sp)
            addi $sp, $sp, -4
            sw $a2, 0($sp)
            addi $sp, $sp, -4
            sw $a3, 0($sp)
            addi $sp, $sp, -4
            sw $t1, 0($sp)
            addi $sp, $sp, -4
            sw $t2, 0($sp)
            addi $sp, $sp, -4
            sw $t4, 0($sp)
            addi $sp, $sp, -4
            sw $t6, 0($sp)
            addi $sp, $sp, -4
            sw $t7, 0($sp)
            addi $sp, $sp, -4
            sw $t8, 0($sp)
            addi $sp, $sp, -4
            sw $t9, 0($sp)
            jal check_four_in_a_row
            lw $t9, 0($sp)
            addi $sp, $sp, 4
            lw $t8, 0($sp)
            addi $sp, $sp, 4
            lw $t7, 0($sp)
            addi $sp, $sp, 4
            lw $t6, 0($sp)
            addi $sp, $sp, 4
            lw $t4, 0($sp)
            addi $sp, $sp, 4
            lw $t2, 0($sp)
            addi $sp, $sp, 4
            lw $t1, 0($sp)
            addi $sp, $sp, 4
            lw $a3, 0($sp)
            addi $sp, $sp, 4
            lw $a2, 0($sp)
            addi $sp, $sp, 4
            lw $a1, 0($sp)
            addi $sp, $sp, 4
            lw $a0, 0($sp)
            addi $sp, $sp, 4
            
            addi $t4, $t4, 16
            j start_row
        prev_row:
            li $s5, 25
            li $s6, 6
            sll $s5, $s5, 2
            sll $s6, $s6, 7
            add $s7, $t0, $s5
            add $s7, $s7, $s6
    
            beq $t4, $s7, end_check_rows  # finished checking rows, check the columns
            addi $t4, $t4, -128  # moves to the previous row
            sub $t4, $t4, $a2    # moves to the first column of the previous row
            j start_row
        new_column:
            addi $t4, $t4, 4
            j start_row
    end_check_rows:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

check_columns:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a2, 23       # height of the inside of the bottle
    sll $a2, $a2, 7  # offset to get the offset of the height of the inside of the bottle

    li $t1, 8        # the leftmost column
    sll $t1, $t1, 2  # offset to get to leftmost column
    li $t2, 28       # the bottom row
    sll $t2, $t2, 7  # offset to get to the bottom row
    add $t4, $t0, $t1
    add $t4, $t4, $t2

    # then, check the columns
    start_column:
        lw $t6, 0($t4)         # the current colour
        li $a0, 1              # the current count of the colour
        beq $t6, $a3, next_column # white reached, move right to the next column
        
        # check if we're at the opening of the bottle (x=15,16,17)
        li $t8, 15
        li $t9, 5
        sll $t8, $t8, 2
        sll $t9, $t9, 7
        add $t2, $t0, $t8
        add $t2, $t2, $t9
        lw $t8, 0($t2)
        bnez $t8, q_pressed
        beq $t4, $t2, next_column
        
        addi $t2, $t2, 4  # moves to column 16
        lw $t8, 0($t2)
        bnez $t8, q_pressed
        beq $t4, $t2, next_column
    
        addi $t2, $t2, 4  # moves to column 17
        lw $t8, 0($t2)
        bnez $t8, q_pressed
        beq $t4, $t2, next_column

        beqz $t6, new_row   # black reached, move to a new row (since we're not at the bottle opening)
        
        # check the next pixels to see if they match
        check_column:
            addi $t4, $t4, -128
            lw $t7, 0($t4)
            beqz $t7, start_column      # colour is black, start at this position
            bne $t7, $t6, start_column  # colours don't match, start at this position
            addi $a0, $a0, 1 # increase count of colour by 1
            beq $a0, 4, erase_consecutive_column
            j check_column
        erase_consecutive_column:
            la $t8, VIRUS_LOCATIONS
            lw $t9, 0($t8)
            beq $t4, $t9, first_column_virus
            lw $t9, 8($t8)
            beq $t4, $t9, second_column_virus
            lw $t9, 16($t8)
            beq $t4, $t9, third_column_virus
            lw $t9, 24($t8)
            beq $t4, $t9, fourth_column_virus
            j continue_erasing_column

            first_column_virus:
                jal remove_first_virus
                j continue_erasing_column
            second_column_virus:
                jal remove_second_virus
                j continue_erasing_column
            third_column_virus:
                jal remove_third_virus
                j continue_erasing_column
            fourth_column_virus:
                jal remove_fourth_virus
            continue_erasing_column:
                sw $zero, 0($t4)
                addi $t4, $t4, 128
                addi $a0, $a0, -1
                beqz $a0, end_consecutive_column
                j erase_consecutive_column
        end_consecutive_column:
            addi $sp, $sp, -4
            sw $a0, 0($sp)
            addi $sp, $sp, -4
            sw $a1, 0($sp)
            addi $sp, $sp, -4
            sw $a2, 0($sp)
            addi $sp, $sp, -4
            sw $a3, 0($sp)
            jal play_four_in_a_row_sound  # destroys, v0, a0-3
            lw $a3, 0($sp)
            addi $sp, $sp, 4
            lw $a2, 0($sp)
            addi $sp, $sp, 4
            lw $a1, 0($sp)
            addi $sp, $sp, 4
            lw $a0, 0($sp)
            
            # after erasing, do a small delay so the user can see the display before
            sw $a0, 0($sp)
            li $v0, 32
            li $a0, 450
            syscall
            lw $a0, 0($sp)
            
            sw $a0, 0($sp)
            addi $sp, $sp, -4
            sw $a1, 0($sp)
            addi $sp, $sp, -4
            sw $t1, 0($sp)
            addi $sp, $sp, -4
            sw $t2, 0($sp)
            addi $sp, $sp, -4
            sw $t3, 0($sp)
            addi $sp, $sp, -4
            sw $t4, 0($sp)
            addi $sp, $sp, -4
            sw $t5, 0($sp)
            jal drop_propagate # destroys a0-1, t1-5
            lw $t5, 0($sp)
            addi $sp, $sp, 4
            lw $t4, 0($sp)
            addi $sp, $sp, 4
            lw $t3, 0($sp)
            addi $sp, $sp, 4
            lw $t2, 0($sp)
            addi $sp, $sp, 4
            lw $t1, 0($sp)
            addi $sp, $sp, 4
            lw $a1, 0($sp)
            addi $sp, $sp, 4
            lw $a0, 0($sp)
            
            # after dropping, do a small delay
            sw $a0, 0($sp)
            li $v0, 32
            li $a0, 800
            syscall
            lw $a0, 0($sp)
            
            # after propagating the drop, check for new formations
            sw $a0, 0($sp)
            addi $sp, $sp, -4
            sw $a1, 0($sp)
            addi $sp, $sp, -4
            sw $a2, 0($sp)
            addi $sp, $sp, -4
            sw $a3, 0($sp)
            addi $sp, $sp, -4
            sw $t1, 0($sp)
            addi $sp, $sp, -4
            sw $t2, 0($sp)
            addi $sp, $sp, -4
            sw $t4, 0($sp)
            addi $sp, $sp, -4
            sw $t6, 0($sp)
            addi $sp, $sp, -4
            sw $t7, 0($sp)
            addi $sp, $sp, -4
            sw $t8, 0($sp)
            addi $sp, $sp, -4
            sw $t9, 0($sp)
            jal check_four_in_a_row
            lw $t9, 0($sp)
            addi $sp, $sp, 4
            lw $t8, 0($sp)
            addi $sp, $sp, 4
            lw $t7, 0($sp)
            addi $sp, $sp, 4
            lw $t6, 0($sp)
            addi $sp, $sp, 4
            lw $t4, 0($sp)
            addi $sp, $sp, 4
            lw $t2, 0($sp)
            addi $sp, $sp, 4
            lw $t1, 0($sp)
            addi $sp, $sp, 4
            lw $a3, 0($sp)
            addi $sp, $sp, 4
            lw $a2, 0($sp)
            addi $sp, $sp, 4
            lw $a1, 0($sp)
            addi $sp, $sp, 4
            lw $a0, 0($sp)
            addi $sp, $sp, 4

            addi $t4, $t4, -512  # moves up 4 rows to account for the backtrack in erase_consecutive_column
            j start_column
        next_column:
            li $s5, 24
            li $s6, 5
            sll $s5, $s5, 2
            sll $s6, $s6, 7
            add $s7, $t0, $s5
            add $s7, $s7, $s6
    
            beq $t4, $s7, end_check_columns
        
            addi $t4, $t4, 4     # moves to the next column
            add $t4, $t4, $a2    # moves to the last row of the next column
            j start_column
        new_row:
            addi $t4, $t4, -128
            j start_column
    
    end_check_columns:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

drop_propagate:
    # destroys a0, a1
    # destroys t1, t2, t3, t4, t5
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, DISPLAY
    li $a0, 8
    li $a1, 28
    sll $a0, $a0, 2
    sll $a1, $a1, 7

    add $t1, $t0, $a0
    add $t1, $t1, $a1
    
    li $a0, 25
    li $a1, 28
    sll $a0, $a0, 2
    sll $a1, $a1, 7
    add $t2, $t0, $a0
    add $t2, $t2, $a1

    # t1: current position
    # t2: end position
    
    find_black_position:
        beq $t1, $t2, end_drop_propagate  # reached the end
        li $a0, 15
        li $a1, 5
        sll $a0, $a0, 2
        sll $a1, $a1, 7
        add $t3, $t0, $a0
        add $t3, $t3, $a1
        beq $t1, $t3, propagate_next_column
        addi $t3, $t3, 4
        beq $t1, $t3, propagate_next_column
        addi $t3, $t3, 4
        beq $t1, $t3, propagate_next_column
        lw $t4, 0($t1)
        beq $t4, 0xffffff, propagate_next_column
        
        # check if pixel is black
        lw $t4, 0($t1)
        bnez $t4, keep_looking_for_black  # not black, keep looking
        j stop_looking_for_black          # found black, stop looking
    
        keep_looking_for_black:
            addi $t1, $t1, -128
            j find_black_position
        stop_looking_for_black:
            add $t5, $t1, -128
        # now, t1 is our black position
        # now, t5 is our potentially coloured position
        
        # after finding it, scan upwards for the first coloured pixel
        find_coloured_position:
            # check if our pixel is white
            lw $t4, 0($t5)
            beq $t4, 0xffffff, end_find_coloured_position
            # checks if we're at the opening of the bottle
            beq $t5, $t3, end_find_coloured_position
            addi $t3, $t3, -4
            beq $t5, $t3, end_find_coloured_position
            addi $t3, $t3, -4
            beq $t5, $t3, end_find_coloured_position
            # since we moved to two spots to the left, undo that change
            addi $t3, $t3, 8
            
            beqz $t4, keep_looking_for_coloured
            la $a0, VIRUS_LOCATIONS
            lw $a1, 0($a0)
            beq $t5, $a1, propagate_virus_found
            lw $a1, 8($a0)
            beq $t5, $a1, propagate_virus_found
            lw $a1, 16($a0)
            beq $t5, $a1, propagate_virus_found
            lw $a1, 24($a0)
            beq $t5, $a1, propagate_virus_found
            j stop_looking_for_coloured  # not a virus, stop looking
            
            propagate_virus_found:
                # move our black position to the one just above the virus
                move $t1, $t5
                addi $t1, $t1, -128
                j find_black_position
            keep_looking_for_coloured:
                addi $t5, $t5, -128
                j find_coloured_position
            stop_looking_for_coloured:
                # move our coloured position to the black position
                sw $t4, 0($t1)
                sw $zero, 0($t5)
                addi $t1, $t1, -128  # moves our black pixel up
                addi $t5, $t5, -128  # moves our coloured pixel up
                j find_coloured_position
            # if the colour is white/at the opening, move t1 to become that position (so we avoid complicated variable offsets)
            end_find_coloured_position:
                move $t1, $t5
                j propagate_next_column
    propagate_next_column:
        li $a0, 23         # height of the inside of the bottle
        sll $a0, $a0, 7    # converts to address offset
        addi $t1, $t1, 4   # moves to next column
        add $t1, $t1, $a0  # moves to the bottom row
        j find_black_position
    end_drop_propagate:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

remove_first_virus:
    # removes this location as a virus
    # prevents nasty bug when player eliminates in this position again
    sw $zero, 0($t8)
    lw $t8, 4($t8)
    sw $zero, 0($t8)
    la $t8, ELIMINATIONS
    lw $t8, 0($t8)
    addi $t8, $t8, 1
    sw $t8, ELIMINATIONS
    jr $ra
remove_second_virus:
    # removes this location as a virus
    # prevents nasty bug when player eliminates in this position again
    sw $zero, 8($t8)
    lw $t8, 12($t8)
    sw $zero, 0($t8)
    la $t8, ELIMINATIONS
    lw $t8, 0($t8)
    addi $t8, $t8, 1
    sw $t8, ELIMINATIONS
    jr $ra
remove_third_virus:
    # removes this location as a virus
    # prevents nasty bug when player eliminates in this position again
    sw $zero, 16($t8)
    lw $t8, 20($t8)
    sw $zero, 0($t8)
    la $t8, ELIMINATIONS
    lw $t8, 0($t8)
    addi $t8, $t8, 1
    sw $t8, ELIMINATIONS
    jr $ra
remove_fourth_virus:
    # removes this location as a virus
    # prevents nasty bug when player eliminates in this position again
    sw $zero, 24($t8)
    lw $t8, 28($t8)
    sw $zero, 0($t8)
    la $t8, ELIMINATIONS
    lw $t8, 0($t8)
    addi $t8, $t8, 1
    sw $t8, ELIMINATIONS
    jr $ra

keyboard_input:
    lw $a1, 4($t0)
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    beq $a1, 0x71, q_pressed     # q pressed, quit the program
    beq $a1, 0x70, p_pressed     # p pressed, pause the game
    beq $a1, 0x77, w_pressed     # w pressed, rotate clockwise
    beq $a1, 0x61, a_pressed     # a pressed, move left
    beq $a1, 0x73, user_s_press  # s pressed, move down
    beq $a1, 0x64, d_pressed     # d pressed, move right
    j end_keyboard_input
    
    user_s_press:
        jal play_move_down_sound
        jal s_pressed

    end_keyboard_input:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

# quits the program
q_pressed:
    lw $a0, BLACK
    jal clear_screen
    jal draw_game_over
    jal play_game_over_sound
    
    end_loop:
        lw $t0, KEYBOARD
        lw $t8, 0($t0)
        beq $t8, 1, end_input
        j end_loop
        end_input:
            lw $a1, 4($t0)
            beq $a1, 0x71, end_game
            beq $a1, 0x72, restart
            j end_input
    end_game:
        lw $a0, WHITE
        jal clear_screen
        jal draw_peace_mario
        jal play_game_over_sound
        li $v0, 10
        syscall
    restart: j main

# pauses the game
p_pressed:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal copy_display
    lw $a0, BLACK
    jal clear_screen
    jal draw_pause_screen
    jal play_pause_sound

    pause_loop:
        lw $t0, KEYBOARD
        lw $t8, 0($t0)
        beq $t8, 1, pause_input
        j pause_loop
        pause_input:
            lw $a1, 4($t0)
            beq $a1, 0x71, end_game
            beq $a1, 0x70, end_pause
            j pause_input
    end_pause:
        jal unpause
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

# rotates the active capsule clockwise
w_pressed:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal get_positions
    
    la $s0, CAPSULE
    lw $s7, 16($s0)

    beq $s7, 0, rotation_one
    beq $s7, 1, rotation_two
    beq $s7, 2, rotation_three
    beq $s7, 3, rotation_four
    
    rotation_one:
        # (0) vertical, turn it horizontal
        # - (X1, Y1) at top left
        # - (X2, Y2) at bottom left
        jal get_positions             # gets our current positions
        addi $v0, $v0, 4              # move to the right
        lw $v0, 0($v0)                # get the colour of the right pixel
        bne $v0, $zero, end_rotation  # check if the right pixel isn't black

        # perform the rotation (because the pixel is black -> move is valid)
        li $a0, 0
        li $a1, 0
        li $a2, 1
        li $a3, 1
        j change_orientation
    rotation_two:
        # (1) horizontal, turn it vertical
        # - (X1, Y1) at bottom right
        # - (X2, Y2) at bottom left
        jal get_positions             # get our current positions
        addi $v0, $v0, -128           # move upwards
        lw $v0, 0($v0)                # get the colour of the pixel above
        bne $v0, $zero, end_rotation  # check if the pixel above isn't black
        
        # perform the rotation (because the pixel is black -> move is valid)
        li $a0, 0
        li $a1, -1
        li $a2, -1
        li $a3, 0
        j change_orientation
    rotation_three:
        # (2) vertical, turn it horizontal
        # - (X1, Y1) at bottom left
        # - (X2, Y2) at top left
        jal get_positions             # get our current positions
        addi $v1, $v1, 4              # move to the right
        lw $v1, 0($v1)                # get the colour of the right pixel
        bne $v1, $zero, end_rotation  # check if the right pixel isn't black
    
        # perform the rotation (because the pixel is black -> move is valid)
        li $a0, 1
        li $a1, 1
        li $a2, 0
        li $a3, 0
        j change_orientation
    rotation_four:
        # (3) horizontal, turn it vertical
        # - (X1, Y1) at bottom left
        # - (X2, Y2) at bottom right
        jal get_positions             # get our current positions
        addi $v1, $v1, -128           # move upwards
        lw $v1, 0($v1)                # get the colour of the pixel above
        bne $v1, $zero, end_rotation  # check if the pixel above isn't black
       
        # perform the rotation (because the pixel is black -> move is valid)
        li $a0, -1
        li $a1, 0
        li $a2, 0
        li $a3, -1
        sw $zero, 16($s0)      # updates our orientation
        j perform_rotation
    change_orientation:
        addi $s7, $s7, 1       # increments by 1
        sw $s7, 16($s0)        # updates our orientation
    perform_rotation:
        jal process_movement
        jal play_rotate_sound
    end_rotation:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

# moves the active capsule left
a_pressed:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal get_positions
    
    la $s0, CAPSULE
    lw $t0, 16($s0)         # get the current orientation
    addi $v0, $v0, -4       # move to the left pixel
    addi $v1, $v1, -4       # move to the left pixel
    lw $v0, 0($v0)          # get the colour from the address
    lw $v1, 0($v1)          # get the colour from the address
    beq $t0, 1, check_a_o1  # check orientation 1
    beq $t0, 3, check_a_o3  # check orientation 3
    
    check_a_verticals:                 # all the vertical orientations are combinable
        bne $v0, $zero, end_a_pressed  # move not possible
        bne $v1, $zero, end_a_pressed  # move not possible
        j move_a
    check_a_o1:
        bne $v0, $zero, end_a_pressed  # move not possible
        j move_a
    check_a_o3:
        bne $v1, $zero, end_a_pressed  # move not possible
        j move_a

    move_a:                            # perform the move
        li $a0, -1
        li $a1, 0
        li $a2, -1
        li $a3, 0
        jal process_movement
        jal play_move_left_sound
    
    end_a_pressed:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

# moves the active capsule down
s_pressed:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal get_positions
    la $s0, CAPSULE
    lw $s7, 16($s0)
    addi $v0, $v0, 128
    addi $v1, $v1, 128
    beq $s7, 0, check_s_o0
    beq $s7, 2, check_s_o2

    check_s_horizontals: # all horizontal positions are combinable
        lw $v0, 0($v0)
        lw $v1, 0($v1)
        bne $v0, $zero, update_capsules
        bne $v1, $zero, update_capsules
        j move_down
    check_s_o0:
        lw $v0, 0($v0)
        bne $v0, $zero, update_capsules
        j move_down
    check_s_o2:
        lw $v1, 0($v1)
        bne $v1, $zero, update_capsules
        j move_down
    move_down:
        li $a0, 0
        li $a1, 1
        li $a2, 0
        li $a3, 1
        jal process_movement
        j end_s_pressed
    update_capsules:
        jal check_four_in_a_row
        # t1: previous capsule data
        # t7: next capsule data
        la $t1, Q1_CAPSULE
        la $t7, ACTIVE_CAPSULE
        jal move_capsule
        la $t1, Q2_CAPSULE
        la $t7, Q1_CAPSULE
        jal move_capsule
        la $t1, Q3_CAPSULE
        la $t7, Q2_CAPSULE
        jal move_capsule
        la $t1, Q4_CAPSULE
        la $t7, Q3_CAPSULE
        jal move_capsule
        la $t1, Q4_CAPSULE
        jal draw_capsule
        jal reset_active_capsule   # reset the active capsule coords
    end_s_pressed:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

# moves the active capsule right
d_pressed:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal get_positions
    
    la $s0, CAPSULE
    lw $t0, 16($s0)         # get the current orientation
    addi $v0, $v0, 4        # move to the right pixel
    addi $v1, $v1, 4        # move to the right pixel
    lw $v0, 0($v0)          # get the colour from the address
    lw $v1, 0($v1)          # get the colour from the address
    beq $t0, 1, check_d_o1  # check orientation 1
    beq $t0, 3, check_d_o3  # check orientation 3
    
    check_d_verticals:                 # all the vertical orientations are combinable
        bne $v0, $zero, end_d_pressed  # move not possible
        bne $v1, $zero, end_d_pressed  # move not possible
        j move_d                       # perform the move
    check_d_o1:
        bne $v1, $zero, end_d_pressed  # move not possible
        j move_d                       # perform the move
    check_d_o3:
        bne $v0, $zero, end_d_pressed  # move not possible
        j move_d                       # perform the move
    
    move_d:
        li $a0, 1
        li $a1, 0
        li $a2, 1
        li $a3, 0
        jal process_movement
        jal play_move_right_sound
    
    end_d_pressed:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

get_positions:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $a0, 0
    li $a1, 0
    li $a2, 0
    li $a3, 0
    jal process_movement
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

process_movement:
    # a0: X2 column change (0=none, -1=left, 1=right)
    # a1: Y2 row change    (0=none, -1=up, 1=down)
    # a2: X1 column change (0=none, -1=left, 1=right)
    # a3: Y1 row change    (0=none, -1=up, 1=down)
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, DISPLAY
    lw $t1, BLACK
    
    # loads our column/row positions
    la $s0, CAPSULE
    lw $t2, 8($s0)
    lw $t3, 12($s0)
    lw $t4, 0($s0)
    lw $t5, 4($s0)
    
    # converts column/row positions to address offsets
    sll $t2, $t2, 2
    sll $t3, $t3, 7
    sll $t4, $t4, 2
    sll $t5, $t5, 7
    
    # find current position of (X2, Y2)
    add $t6, $t0, $t2  # adds X2 x-offset
    add $t6, $t6, $t3  # adds Y2 y-offset 
    lw $t7, 0($t6)     # gets the colour at (X2, Y2)

    # find current position of (X1, Y1)
    add $t8, $t0, $t4  # adds X1 x-offset
    add $t8, $t8, $t5  # adds Y1 y-offset 
    lw $t9, 0($t8)     # gets the colour at (X1, Y1)

    # now, t2, t3, t4, and t5 are the column/row addresses
    # now, t6 (X2, Y2) and t8 (X1, Y1) are the previous positions
    # now, t7 (X2, Y2) and t9 (X1, Y1) are the previous colours
    
    sw $t1, 0($t6)     # paint previous black
    sw $t1, 0($t8)     # paint previous black
    # ^ ensures that one isn't blacked out before being moved

    sll $a0, $a0, 2    # multiply a0 by 4 to get column address offset
    add $t6, $t6, $a0  # adds the column address offset
    sll $a1, $a1, 7    # multiply a1 by 128 to get row address offset
    add $t6, $t6, $a1  # adds the row address offset
    sw $t7, 0($t6)     # paint colour at new position (t6)
    srl $a0, $a0, 2    # divide a0 by 4 to get column offset
    srl $a1, $a1, 7    # divide a1 by 128 to get row offset
    srl $t2, $t2, 2    # divide t2 by 4 to get the old column number
    srl $t3, $t3, 7    # divide t3 by 128 to get the old row number
    add $t2, $t2, $a0  # moves the column in the direction of a0
    add $t3, $t3, $a1  # moves the row in the direction of a1
    sw $t2, 8($s0)     # updates X2
    sw $t3, 12($s0)    # updates Y2

    sll $a2, $a2, 2    # multiply a2 by 4 to get column address offset
    add $t8, $t8, $a2  # adds the column address offset
    sll $a3, $a3, 7    # multiply a3 by 128 to get row address offset
    add $t8, $t8, $a3  # adds the row address offset
    sw $t9, 0($t8)     # paint colour at new position (t8)
    srl $a2, $a2, 2    # divide a2 by 4 to get column offset
    srl $a3, $a3, 7    # divide a3 by 128 to get row offset
    srl $t4, $t4, 2    # divide t4 by 4 to get the old column number
    srl $t5, $t5, 7    # divide t5 by 128 to get the old row number
    add $t4, $t4, $a2  # moves the column in the direction of a2
    add $t5, $t5, $a3  # moves the row in the direction of a3
    sw $t4, 0($s0)     # updates X1
    sw $t5, 4($s0)     # updates Y1

    # our function return values
    move $v0, $t6      # v0: the new address of (X2, Y2)
    move $v1, $t8      # v1: the new address (X1, Y1)

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

draw_viruses:
    lw $t0, DISPLAY
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $t1, 0     # our count variable
    li $t3, 4
    sll $t3, $t3, 2
    add $t4, $t0, $t3
    li $t3, 14
    sll $t3, $t3, 7
    add $t4, $t4, $t3
    
    draw_virus:
        li $a3, 3
        jal generate_random_number
        jal update_colour
        # now, the random colour is in a2
        
        # get the random position for the lower half of the bottle
        li $a3, 17                 # we want these columns [8, 25)
        jal generate_random_number
        
        sll $a0, $a0, 2            # get the non-offsetted address
        addi $a0, $a0, 32          # offset to get actual position
        add $t2, $t0, $a0          # add offset to t0
    
        li $a3, 17                 # we want these rows: [12, 29)
        jal generate_random_number

        sll $a0, $a0, 7            # get the non-offseted address
        addi $a0, $a0, 1536        # offset to get the actual position
        add $t2, $t2, $a0          # add offset to t2

        la $t5, VIRUS_LOCATIONS
        # check if this location has already been drawn to
        # avoids highly unlikely possibility of overwriting a virus pixel
        lw $t6, 0($t5)
        beq $t2, $t6, redo_virus
        lw $t6, 8($t5)
        beq $t2, $t6, redo_virus
        lw $t6, 16($t5)
        beq $t2, $t6, redo_virus
        lw $t6, 24($t5)
        beq $t2, $t6, redo_virus
        
        sw $a2, 0($t2)    # draw the virus pixel
        sw $a2, 0($t4)    # draws the viruses on the side
        sw $t2, 24($t5)   # stores the virus location
        sw $t4, 28($t5)   # stores the virus side panel location
        
        beq $t1, 0, set_virus_one_position
        beq $t1, 1, set_virus_two_position
        beq $t1, 2, set_virus_three_position
        
        j increase_virus_count
        
        set_virus_one_position:
            sw $t2, 0($t5)   # stores the virus location
            sw $t4, 4($t5)   # stores the virus side panel location
            j increase_virus_count
        set_virus_two_position:
            sw $t2, 8($t5)   # stores the virus location
            sw $t4, 12($t5)  # stores the virus side panel location
            j increase_virus_count
        set_virus_three_position:
            sw $t2, 16($t5)  # stores the virus location
            sw $t4, 20($t5)  # stores the virus side panel location
        increase_virus_count:
            addi $t1, $t1, 1           # increment our loop variable
            addi $t4, $t4, 256         # updates side panel virus location
            beq $t1, 4, draw_virus_end # end drawing after 3 viruses drawn
            j draw_virus
        redo_virus:
            j draw_virus
    draw_virus_end:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

move_capsule:
    # t1: previous capsule data
    # t7: next capsule data
    lw $t0, DISPLAY
    la $t8, ACTIVE_CAPSULE
    bne $t7, $t8, actually_move_capsule
    
    # now, the next capsule is the ACTIVE_CAPSULE
    # check if the entrance is covered
    
    lw $t8, 0($t7)
    sll $t8, $t8, 2
    add $t9, $t0, $t8
    lw $t8, 4($t7)
    sll $t8, $t8, 7
    add $t9, $t9, $t8
    
    # we have the top-most, move down two rows
    addi $t9, $t9, 256
    lw $t8, 0($t9)
    bnez $t8, q_pressed  # check directly beneath
    # otherwise, move the capsule

    actually_move_capsule:
        lw $t2, 0($t1)
        lw $t3, 4($t1)
        sll $t2, $t2, 2
        sll $t3, $t3, 7
        
        add $t4, $t0, $t2
        add $t4, $t4, $t3
        lw $t5, 0($t4)      # gets the previous top colour
        addi $t4, $t4, 128  # moves down a row
        lw $t6, 0($t4)      # gets the previous bottom colour
    
        lw $t2, 0($t7)
        lw $t3, 4($t7)
        sll $t2, $t2, 2
        sll $t3, $t3, 7
        
        add $t4, $t0, $t2
        add $t4, $t4, $t3
        sw $t5, 0($t4)
        add $t4, $t4, 128
        sw $t6, 0($t4)
    
        j return

draw_capsule:
    # t1: address of capsule data (from .data)
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, DISPLAY
    
    lw $t2, 0($t1)   # loads X0
    lw $t3, 4($t1)   # loads Y0
    sll $t2, $t2, 2  # converts to column address offset
    sll $t3, $t3, 7  # converts to row address offset
    add $t4, $t0, $t2
    add $t4, $t4, $t3

    li $a3, 3        # the upper limit of RNG
    jal generate_random_number
    jal update_colour
    sw $a2, 0($t4)
    
    jal generate_random_number
    jal update_colour
    sw $a2, 128($t4)

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

generate_random_number:
    # a3: the upper bound of int generation (exclusive)
    # init parameters for random number generation
    li $v0, 42 # sets generation for the range [0, $a1)
    li $a0, 0  # generator ID
    move $a1, $a3  # sets the upper bound for generation
    syscall # after this, the random int is in $a0
    j return

update_colour:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    beq $a0, 0, set_c1
    beq $a0, 1, set_c2
    beq $a0, 2, set_c3
    
    set_c1:
        lw $a2, C1
        j end_update_colour
    set_c2:
        lw $a2, C2
        j end_update_colour
    set_c3:
        lw $a2, C3
    end_update_colour:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        j return

copy_display:
    lw $t0, DISPLAY
    lw $t1, DISPLAY_COPY
    li $t2, 31 
    li $t3, 31
    sll $t2, $t2, 2
    sll $t3, $t3, 7
    
    add $t4, $t0, $t2
    add $t4, $t4, $t3

    loop_display:
        lw $t5, 0($t0)
        sw $t5, 0($t1)
        beq $t4, $t0, end_loop_display
        addi $t0, $t0, 4
        addi $t1, $t1, 4
        j loop_display
    end_loop_display:
        j return

unpause:
    lw $t0, DISPLAY
    lw $t1, DISPLAY_COPY
    
    li $t2, 31
    li $t3, 31
    sll $t2, $t2, 2
    sll $t3, $t3, 7
    add $t4, $t0, $t2
    add $t4, $t4, $t3
    
    redraw:
        lw $t5, 0($t1)
        sw $t5, 0($t0)
        beq $t0, $t4, end_redraw
        addi $t0, $t0, 4
        addi $t1, $t1, 4
        j redraw
    end_redraw: j return

draw_pause_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $a3, WHITE
    lw $t0, DISPLAY
    
    # draws P
    li $a0, 2
    li $a1, 12
    li $a2, 7
    jal draw_col
    li $a0, 2
    li $a1, 12
    li $a2, 4
    jal draw_row
    li $a0, 2
    li $a1, 15
    li $a2, 4
    jal draw_row
    li $a0, 6
    li $a1, 13
    li $a2, 2
    jal draw_col

    # draws A
    li $a0, 8
    li $a1, 13
    li $a2, 6
    jal draw_col
    li $a0, 12
    li $a1, 13
    li $a2, 6
    jal draw_col
    li $a0, 9
    li $a1, 12
    li $a2, 3
    jal draw_row
    li $a0, 9
    li $a1, 16
    li $a2, 3
    jal draw_row

    # draws U
    li $a0, 14
    li $a1, 12
    li $a2, 6
    jal draw_col
    li $a0, 18
    li $a1, 12
    li $a2, 6
    jal draw_col
    li $a0, 15
    li $a1, 18
    li $a2, 3
    jal draw_row

    # draws S
    li $a0, 21
    li $a1, 12
    li $a2, 3
    jal draw_row
    li $a0, 21
    li $a1, 15
    li $a2, 3
    jal draw_row
    li $a0, 21
    li $a1, 18
    li $a2, 3
    jal draw_row
    li $a0, 20
    li $a1, 13
    li $a2, 2
    jal draw_col
    li $a0, 24
    li $a1, 16
    li $a2, 2
    jal draw_col
    li $a0, 24
    li $a1, 13
    li $a2, 1
    jal draw_row
    li $a0, 20
    li $a1, 17
    li $a2, 1
    jal draw_row

    # draws E
    li $a0, 26
    li $a1, 12
    li $a2, 7
    jal draw_col
    li $a0, 26
    li $a1, 12
    li $a2, 5
    jal draw_row
    li $a0, 26
    li $a1, 18
    li $a2, 5
    jal draw_row
    li $a0, 26
    li $a1, 15
    li $a2, 4
    jal draw_row
    
    # draws the pause symbol
    li $a0, 13
    li $a1, 22
    li $a2, 7
    jal draw_col
    li $a0, 14
    li $a1, 22
    li $a2, 7
    jal draw_col
    li $a0, 17
    li $a1, 22
    li $a2, 7
    jal draw_col
    li $a0, 18
    li $a1, 22
    li $a2, 7
    jal draw_col
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

draw_game_over:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $a3, WHITE   # the colour of our bottle
    lw $t0, DISPLAY # the top left of our display
    
    # draws G
    li $a0, 5
    li $a1, 8
    li $a2, 3
    jal draw_row
    li $a0, 4
    li $a1, 9
    li $a2, 5
    jal draw_col
    li $a0, 5
    li $a1, 14
    li $a2, 3
    jal draw_row
    li $a0, 7
    li $a1, 12
    li $a2, 2
    jal draw_row
    li $a0, 8
    li $a1, 9
    li $a2, 1
    jal draw_row    
    li $a0, 8
    li $a1, 13
    li $a2, 1
    jal draw_row
    
    # draws A
    li $a0, 11
    li $a1, 8
    li $a2, 3
    jal draw_row
    li $a0, 11
    li $a1, 12
    li $a2, 3
    jal draw_row
    li $a0, 10
    li $a1, 9
    li $a2, 6
    jal draw_col
    li $a0, 14
    li $a1, 9
    li $a2, 6
    jal draw_col
    
    # draws M
    li $a0, 16
    li $a1, 8
    li $a2, 7
    jal draw_col
    li $a0, 20
    li $a1, 8
    li $a2, 7
    jal draw_col
    li $a0, 18
    li $a1, 10
    li $a2, 2
    jal draw_col
    li $a0, 17
    li $a1, 9
    li $a2, 1
    jal draw_col
    li $a0, 19
    li $a1, 9
    li $a2, 1
    jal draw_col

    # draws E
    li $a0, 22
    li $a1, 8
    li $a2, 7
    jal draw_col
    li $a0, 23
    li $a1, 8
    li $a2, 4
    jal draw_row
    li $a0, 23
    li $a1, 11
    li $a2, 3
    jal draw_row
    li $a0, 23
    li $a1, 14
    li $a2, 4
    jal draw_row

    # draws O
    li $a0, 5
    li $a1, 17
    li $a2, 3
    jal draw_row
    li $a0, 5
    li $a1, 23
    li $a2, 3
    jal draw_row
    li $a0, 4
    li $a1, 18
    li $a2, 5
    jal draw_col
    li $a0, 8
    li $a1, 18
    li $a2, 5
    jal draw_col

    # draws V
    li $a0, 10
    li $a1, 17
    li $a2, 4
    jal draw_col
    li $a0, 14
    li $a1, 17
    li $a2, 4
    jal draw_col
    li $a0, 11
    li $a1, 21
    li $a2, 2
    jal draw_col
    li $a0, 13
    li $a1, 21
    li $a2, 2
    jal draw_col
    li $a0, 12
    li $a1, 23
    li $a2, 1
    jal draw_col
    
    # draws E
    li $a0, 16
    li $a1, 17
    li $a2, 7
    jal draw_col
    li $a0, 17
    li $a1, 17
    li $a2, 4
    jal draw_row
    li $a0, 17
    li $a1, 20
    li $a2, 3
    jal draw_row
    li $a0, 17
    li $a1, 23
    li $a2, 4
    jal draw_row

    # draws R
    li $a0, 22
    li $a1, 17
    li $a2, 7
    jal draw_col
    li $a0, 22
    li $a1, 17
    li $a2, 4
    jal draw_row
    li $a0, 22
    li $a1, 20
    li $a2, 4
    jal draw_row
    li $a0, 26
    li $a1, 18
    li $a2, 2
    jal draw_col
    li $a0, 26
    li $a1, 21
    li $a2, 3
    jal draw_col

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

reset_active_capsule:
    la $t0, ACTIVE_CAPSULE
    la $t1, CAPSULE
    lw $t2, 0($t0)
    lw $t3, 4($t0)
    lw $t4, 8($t0)
    lw $t5, 12($t0)
    lw $t6, 16($t0)
    sw $t2, 0($t1)
    sw $t3, 4($t1)
    sw $t4, 8($t1)
    sw $t5, 12($t1)
    sw $t6, 16($t1)
    j return

draw_peace_mario:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    lw $t0, DISPLAY

    # dark red
    li $a3, 0xb71c1c
    li $a0, 15
    li $a1, 2
    li $a2, 4
    jal draw_row
    li $a0, 14
    li $a1, 3
    li $a2, 1
    jal draw_row
    li $a0, 21
    li $a1, 4
    li $a2, 1
    jal draw_row
    li $a0, 19 
    li $a1, 3
    li $a2, 2
    jal draw_row
    li $a0, 21
    li $a1, 4
    li $a2, 1
    jal draw_row
    li $a0, 22
    li $a1, 5
    li $a2, 4
    jal draw_col
    li $a0, 9
    li $a1, 11
    li $a2, 4
    jal draw_row
    li $a0, 9
    li $a1, 11
    li $a2, 5
    jal draw_col
    li $a0, 10
    li $a1, 16
    li $a2, 3
    jal draw_col
    li $a0, 12
    li $a1, 11
    li $a2, 4
    jal draw_col
    li $a0, 13
    li $a1, 15
    li $a2, 1
    jal draw_col
    li $a0, 20
    li $a1, 16
    li $a2, 1
    jal draw_col
    li $a0, 21
    li $a1, 17
    li $a2, 1
    jal draw_col
    li $a0, 16
    li $a1, 18
    li $a2, 2
    jal draw_row
    
    # light red
    li $a3, 0xd50000
    li $a0, 15
    li $a1, 3
    li $a2, 2
    jal draw_row
    li $a0, 18
    li $a1, 3
    li $a2, 1
    jal draw_row
    li $a0, 20
    li $a1, 5
    li $a2, 1
    jal draw_row
    li $a0, 19
    li $a1, 4
    li $a2, 2
    jal draw_row
    li $a0, 21
    li $a1, 5
    li $a2, 2
    jal draw_col
    li $a0, 14
    li $a1, 4
    li $a2, 2
    jal draw_row
    li $a0, 10
    li $a1, 12
    li $a2, 4
    jal draw_col
    li $a0, 11
    li $a1, 12
    li $a2, 8
    jal draw_col
    li $a0, 12
    li $a1, 15
    li $a2, 4
    jal draw_col
    li $a0, 13
    li $a1, 16
    li $a2, 3
    jal draw_col
    li $a0, 16
    li $a1, 17
    li $a2, 2
    jal draw_row
    li $a0, 19
    li $a1, 16
    li $a2, 1
    jal draw_col
    li $a0, 20
    li $a1, 17
    li $a2, 2
    jal draw_col
    
    # black
    li $a3, 0x000000
    li $a0, 13
    li $a1, 3
    li $a2, 8
    jal draw_col
    li $a0, 14
    li $a1, 5
    li $a2, 6
    jal draw_row
    li $a0, 14
    li $a1, 6
    li $a2, 7
    jal draw_row
    li $a0, 14
    li $a1, 7
    li $a2, 8
    jal draw_row
    li $a0, 20
    li $a1, 8
    li $a2, 2
    jal draw_row
    li $a0, 9
    li $a1, 3
    li $a2, 2
    jal draw_row
    li $a0, 12
    li $a1, 3
    li $a2, 2
    jal draw_row
    li $a0, 11
    li $a1, 4
    li $a2, 1
    jal draw_row
    li $a0, 11
    li $a1, 7
    li $a2, 2
    jal draw_row
    li $a0, 8
    li $a1, 7
    li $a2, 4
    jal draw_col
    li $a0, 9
    li $a1, 9
    li $a2, 3
    jal draw_row
    li $a0, 10
    li $a1, 8
    li $a2, 1
    jal draw_row
    li $a0, 9
    li $a1, 4
    li $a2, 1
    jal draw_row
    li $a0, 10
    li $a1, 5
    li $a2, 1
    jal draw_row
    li $a0, 9
    li $a1, 6
    li $a2, 3
    jal draw_row
    li $a0, 11
    li $a1, 7
    li $a2, 3
    jal draw_row
    li $a0, 15
    li $a1, 9
    li $a2, 2
    jal draw_col
    li $a0, 18
    li $a1, 9
    li $a2, 2
    jal draw_col
    li $a0, 22
    li $a1, 9
    li $a2, 4
    jal draw_col
    li $a0, 21
    li $a1, 11
    li $a2, 1
    jal draw_col
    li $a0, 14
    li $a1, 14
    li $a2, 6
    jal draw_row
    li $a0, 13
    li $a1, 13
    li $a2, 8
    jal draw_row
    li $a0, 13
    li $a1, 12
    li $a2, 2
    jal draw_row
    li $a0, 19
    li $a1, 12
    li $a2, 2
    jal draw_row
    li $a0, 21
    li $a1, 18
    li $a2, 2
    jal draw_row
    li $a0, 23
    li $a1, 19
    li $a2, 3
    jal draw_col
    li $a0, 22
    li $a1, 22
    li $a2, 1
    jal draw_row
    
    # dark blue
    li $a3, 0x01579b
    li $a0, 12
    li $a1, 19
    li $a2, 1
    jal draw_col
    li $a0, 11
    li $a1, 20
    li $a2, 3
    jal draw_col
    li $a0, 10
    li $a1, 23
    li $a2, 4
    jal draw_col
    li $a0, 10
    li $a1, 26
    li $a2, 4
    jal draw_row
    li $a0, 14
    li $a1, 25
    li $a2, 1
    jal draw_col
    li $a0, 15
    li $a1, 24
    li $a2, 4
    jal draw_row
    li $a0, 18
    li $a1, 24
    li $a2, 3
    jal draw_col
    li $a0, 18
    li $a1, 26
    li $a2, 5
    jal draw_row
    li $a0, 22
    li $a1, 23
    li $a2, 4
    jal draw_col
    li $a0, 21
    li $a1, 20
    li $a2, 3
    jal draw_col
    
    # light blue
    li $a3, 0x0288d1
    li $a0, 11
    li $a1, 23
    li $a2, 3
    jal draw_col
    li $a0, 11
    li $a1, 25
    li $a2, 3
    jal draw_row
    li $a0, 14
    li $a1, 24
    li $a2, 1
    jal draw_col
    li $a0, 15
    li $a1, 23
    li $a2, 4
    jal draw_row
    li $a0, 19
    li $a1, 24
    li $a2, 2
    jal draw_col
    li $a0, 19
    li $a1, 25
    li $a2, 3
    jal draw_row
    li $a0, 21
    li $a1, 23
    li $a2, 2
    jal draw_col
    li $a0, 20
    li $a1, 22
    li $a2, 1
    jal draw_col
    li $a0, 20
    li $a1, 19
    li $a2, 1
    jal draw_col
    li $a0, 14
    li $a1, 17
    li $a2, 2
    jal draw_row
    li $a0, 18
    li $a1, 17
    li $a2, 2
    jal draw_row
    li $a0, 14
    li $a1, 18
    li $a2, 1
    jal draw_row
    li $a0, 13
    li $a1, 19
    li $a2, 1
    jal draw_row
    li $a0, 19
    li $a1, 18
    li $a2, 1
    jal draw_row
    
    # lightest blue
    li $a3, 0x039be5
    li $a0, 12
    li $a1, 20
    li $a2, 5
    jal draw_col
    li $a0, 13
    li $a1, 22
    li $a2, 3
    jal draw_col
    li $a0, 14
    li $a1, 22
    li $a2, 2
    jal draw_col
    li $a0, 14
    li $a1, 19
    li $a2, 6
    jal draw_row
    li $a0, 15
    li $a1, 18
    li $a2, 1
    jal draw_row
    li $a0, 18
    li $a1, 18
    li $a2, 1
    jal draw_row
    li $a0, 15
    li $a1, 19
    li $a2, 4
    jal draw_col
    li $a0, 16
    li $a1, 19
    li $a2, 4
    jal draw_col
    li $a0, 17
    li $a1, 19
    li $a2, 4
    jal draw_col
    li $a0, 18
    li $a1, 19
    li $a2, 4
    jal draw_col
    li $a0, 19
    li $a1, 22
    li $a2, 2
    jal draw_col
    li $a0, 20
    li $a1, 23
    li $a2, 2
    jal draw_col
    
    # yellow
    li $a3, 0xffeb3b
    li $a0, 13
    li $a1, 20
    li $a2, 2
    jal draw_row
    li $a0, 13
    li $a1, 21
    li $a2, 2
    jal draw_row
    li $a0, 19
    li $a1, 20
    li $a2, 2
    jal draw_row
    li $a0, 19
    li $a1, 21
    li $a2, 2
    jal draw_row
    li $a0, 16
    li $a1, 4
    li $a2, 3
    jal draw_row
    li $a0, 17
    li $a1, 3
    li $a2, 1
    jal draw_row
    
    # lighter skin
    li $a3, 0xffe0b2
    li $a0, 16
    li $a1, 9
    li $a2, 3
    jal draw_col
    li $a0, 17
    li $a1, 9
    li $a2, 3
    jal draw_col
    li $a0, 20
    li $a1, 9
    li $a2, 3
    jal draw_col
    li $a0, 21
    li $a1, 9
    li $a2, 2
    jal draw_col
    li $a0, 21
    li $a1, 12
    li $a2, 2
    jal draw_col
    li $a0, 23
    li $a1, 9
    li $a2, 4
    jal draw_col
    li $a0, 20
    li $a1, 14
    li $a2, 1
    jal draw_row
    li $a0, 14
    li $a1, 15
    li $a2, 5
    jal draw_row
    li $a0, 13
    li $a1, 14
    li $a2, 1
    jal draw_row
    li $a0, 13
    li $a1, 11
    li $a2, 1
    jal draw_row
    li $a0, 15
    li $a1, 11
    li $a2, 4
    jal draw_row

    # darker skin
    li $a3, 0xffcc80
    li $a0, 16
    li $a1, 8
    li $a2, 2
    jal draw_row
    li $a0, 15
    li $a1, 12
    li $a2, 4
    jal draw_row
    li $a0, 14
    li $a1, 16
    li $a2, 5
    jal draw_row
    li $a0, 19
    li $a1, 15
    li $a2, 2
    jal draw_row
    li $a0, 21
    li $a1, 14
    li $a2, 1
    jal draw_row
    li $a0, 22
    li $a1, 13
    li $a2, 1
    jal draw_row
    li $a0, 14
    li $a1, 11
    li $a2, 1
    jal draw_row
    li $a0, 19
    li $a1, 11
    li $a2, 1
    jal draw_row

    # dark brown
    li $a3, 0x5d4037
    li $a0, 8
    li $a1, 29
    li $a2, 6
    jal draw_row
    li $a0, 18
    li $a1, 29
    li $a2, 6
    jal draw_row
    li $a0, 9
    li $a1, 28
    li $a2, 5
    jal draw_row
    li $a0, 18
    li $a1, 28
    li $a2, 5
    jal draw_row
    li $a0, 10
    li $a1, 27
    li $a2, 4
    jal draw_row
    li $a0, 18
    li $a1, 27
    li $a2, 4
    jal draw_row
    
    # light brown
    li $a3, 0x795548
    li $a0, 8
    li $a1, 28
    li $a2, 1
    jal draw_row
    li $a0, 9
    li $a1, 27
    li $a2, 1
    jal draw_row
    li $a0, 22
    li $a1, 27
    li $a2, 1
    jal draw_row
    li $a0, 23
    li $a1, 28
    li $a2, 1
    jal draw_row
    
    lw $a3, WHITE
    li $a0, 14
    li $a1, 8
    li $a2, 3
    jal draw_col
    li $a0, 19
    li $a1, 8
    li $a2, 3
    jal draw_col
    li $a0, 15
    li $a1, 8
    li $a2, 1
    jal draw_col
    li $a0, 18
    li $a1, 8
    li $a2, 1
    jal draw_col
    li $a0, 22
    li $a1, 19
    li $a2, 3
    jal draw_col
    li $a0, 21
    li $a1, 19
    li $a2, 1
    jal draw_row
    li $a0, 9
    li $a1, 10
    li $a2, 4
    jal draw_row
    li $a0, 9
    li $a1, 7
    li $a2, 2
    jal draw_row
    li $a0, 9
    li $a1, 8
    li $a2, 1
    jal draw_row
    li $a0, 11
    li $a1, 8
    li $a2, 2
    jal draw_row
    li $a0, 11
    li $a1, 5
    li $a2, 2
    jal draw_row
    li $a0, 10
    li $a1, 4
    li $a2, 1
    jal draw_col
    li $a0, 12
    li $a1, 4
    li $a2, 3
    jal draw_col
    li $a0, 12
    li $a1, 8
    li $a2, 3
    jal draw_col
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

draw_bottle:
    # a0: starting column 
    # a1: starting row
    # a2: length of line
    # a3: the colour
    lw $a3, WHITE   # the colour of our bottle
    lw $t0, DISPLAY # the top left of our display
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # draws the top left of the bottle
    li $a0, 7
    li $a1, 5
    li $a2, 8
    jal draw_row
    
    # draws the top right of the bottle
    li $a0, 18
    li $a1, 5
    li $a2, 8
    jal draw_row

    # draws the bottom of the bottle
    li $a0, 7
    li $a1, 29
    addi $a2, $zero, 19
    jal draw_row

    # draws the left opening of the bottle
    li $a0, 14
    li $a1, 3
    li $a2, 2
    jal draw_col

    # draws the right opening of the bottle
    li $a0, 18
    li $a1, 3
    li $a2, 2
    jal draw_col

    # draws the left of the bottle
    li $a0, 7
    li $a1, 5
    li $a2, 25
    jal draw_col
    
    # draws the right of the bottle
    li $a0, 25
    li $a1, 5
    li $a2, 25
    jal draw_col

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j return

draw_row:
    sll $a0, $a0, 2 # x-offset (4x)
    sll $a1, $a1, 7 # y-offset (128x)
    sll $a2, $a2, 2 # line offset (4x)
    
    add $t1, $t0, $a0 # adds the x offset to t0
    add $t1, $t1, $a1 # adds the y offset to t1
    add $t2, $t1, $a2 # adds the line offset to t1
    
    # now, t1 stores our starting position and t2 stores the ending position
    row_start:
        sw $a3, 0($t1)        # draw the pixel
        addi $t1, $t1, 4      # moves to the next column
        beq $t1, $t2, row_end # done drawing the row
        j row_start           # continue drawing the row
    row_end: j return

draw_col:
    sll $a0, $a0, 2 # x-offset (4x)
    sll $a1, $a1, 7 # y-offset (128x)
    sll $a2, $a2, 7 # line offset (4x)
    
    add $t1, $t0, $a0 # adds the x offset to t0
    add $t1, $t1, $a1 # adds the y offset to t1
    add $t2, $t1, $a2 # adds the line offset to t1
    
    # now, t1 stores our starting position and t2 stores the ending position
    col_start:
        sw $a3, 0($t1)        # draw the pixel
        addi $t1, $t1, 128    # moves to the next row
        beq $t1, $t2, col_end # done drawing the column
        j col_start           # continue drawing the column
    col_end: j return

clear_screen:
    lw $t0, DISPLAY
    li $t1, 31 
    li $t2, 31
    sll $t1, $t1, 2
    sll $t2, $t2, 7

    add $t3, $t0, $t1
    add $t3, $t3, $t2
    
    clear:
        sw $a0, 0($t0)
        beq, $t0, $t3, end_clear_screen
        addi $t0, $t0, 4
        j clear
    end_clear_screen:
        j return

play_four_in_a_row_sound:
    li $v0, 31
    li $a0, 40   # pitch 0-127
    li $a1, 10   # duration in ms
    li $a2, 124  # instrument 0-127
    li $a3, 110   # volume 0-127
    syscall
    j return

load_four_in_a_row_sound:
    li $v0, 31
    li $a0, 40   # pitch 0-127
    li $a1, 10   # duration in ms
    li $a2, 124  # instrument 0-127
    li $a3, 0    # volume 0-127
    syscall
    j return

play_rotate_sound:
    li $v0, 31
    li $a0, 37  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 110  # volume 0-127
    syscall
    j return

load_rotate_sound:
    li $v0, 31
    li $a0, 37  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 0   # volume 0-127
    syscall
    j return

play_move_left_sound:
    li $v0, 31
    li $a0, 35  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 110  # volume 0-127
    syscall
    j return

load_move_left_sound:
    li $v0, 31
    li $a0, 35  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92 # instrument 0-127
    li $a3, 0  # volume 0-127
    syscall
    j return

play_move_down_sound:
    li $v0, 31
    li $a0, 29  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 110  # volume 0-127
    syscall
    j return

load_move_down_sound:
    li $v0, 31
    li $a0, 29  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 0   # volume 0-127
    syscall
    j return

play_move_right_sound:
    li $v0, 31
    li $a0, 38  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 110  # volume 0-127
    syscall
    j return

load_move_right_sound:
    li $v0, 31
    li $a0, 38  # pitch 0-127
    li $a1, 10  # duration in ms
    li $a2, 92  # instrument 0-127
    li $a3, 0   # volume 0-127
    syscall
    j return

play_pause_sound:
    li $v0, 31
    li $a0, 85   # pitch 0-127
    li $a1, 100  # duration in ms
    li $a2, 75   # instrument 0-127
    li $a3, 110   # volume 0-127
    syscall
    j return

load_pause_sound:
    li $v0, 31
    li $a0, 85   # pitch 0-127
    li $a1, 100  # duration in ms
    li $a2, 75   # instrument 0-127
    li $a3, 0    # volume 0-127
    syscall
    j return

play_game_over_sound:
    li $v0, 31
    li $a0, 27
    li $a1, 220
    li $a2, 57
    li $a3, 100
    syscall
    j return

load_game_over_sound:
    li $v0, 31
    li $a0, 50
    li $a1, 220
    li $a2, 57
    li $a3, 0
    syscall
    j return

play_win_sound:
    li $v0, 31
    li $a0, 70
    li $a1, 888
    li $a2, 56
    li $a3, 110
    syscall
    j return

load_win_sound:
    li $v0, 31
    li $a0, 70
    li $a1, 888
    li $a2, 56
    li $a3, 0
    syscall
    j return

return: jr $ra