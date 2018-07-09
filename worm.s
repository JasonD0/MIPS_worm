#
# COMP1521 18s1 -- Assignment 1 -- Worm on a Plane!
#
# Base code by Jashank Jeremy and Wael Alghamdi
# Tweaked (severely) by John Shepherd
# Finished by Jason Do (z5159932)
# Set your tabstop to 8 to make the formatting decent

# Requires:
#  - [no external symbols]

# Provides:
	.globl	wormCol
	.globl	wormRow
	.globl	grid
	.globl	randSeed

	.globl	main
	.globl	clearGrid
	.globl	drawGrid
	.globl	initWorm
	.globl	onGrid
	.globl	overlaps
	.globl	moveWorm
	.globl	addWormToGrid
	.globl	giveUp
	.globl	intValue
	.globl	delay
	.globl	seedRand
	.globl	randValue

	# Let me use $at, please.
	.set	noat

# The following notation is used to suggest places in
# the program, where you might like to add debugging code
#
# If you see e.g. putc('a'), replace by the three lines
# below, with each x replaced by 'a'
#
# print out a single character
# define putc(x)
# 	addi	$a0, $0, x
# 	addiu	$v0, $0, 11
# 	syscall
# 
# print out a word-sized int
# define putw(x)
# 	add 	$a0, $0, x
# 	addiu	$v0, $0, 1
# 	syscall

####################################
# .DATA
	.data

	.align 4
wormCol:	.space	40 * 4
	.align 4
wormRow:	.space	40 * 4
	.align 4
grid:		.space	20 * 40 * 1

randSeed:	.word	0

main__0:	.asciiz "Invalid Length (4..20)"
main__1:	.asciiz "Invalid # Moves (0..99)"
main__2:	.asciiz "Invalid Rand Seed (0..Big)"
main__3:	.asciiz "Iteration "
main__4:	.asciiz "Blocked!\n"

	# ANSI escape sequence for 'clear-screen'
main__clear:	.asciiz "\033[H\033[2J"
#main__clear:	.asciiz "__showpage__\n" # for debugging

giveUp__0:	.asciiz "Usage: "
giveUp__1:	.asciiz " Length #Moves Seed\n"

####################################
# .TEXT <main>
	.text
main:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3, $s4
# Uses: 	$a0, $a1, $v0, $s0, $s1, $s2, $s3, $s4
# Clobbers:	$a0, $a1

# Locals:
#	- `argc' in $s0
#	- `argv' in $s1
#	- `length' in $s2
#	- `ntimes' in $s3
#	- `i' in $s4

# Structure:
#	main
#	-> [prologue]
#	-> main_seed
#	  -> main_seed_t
#	  -> main_seed_end
#	-> main_seed_phi
#	-> main_i_init
#	-> main_i_cond
#	   -> main_i_step
#	-> main_i_end
#	-> [epilogue]
#	-> main_giveup_0
#	 | main_giveup_1
#	 | main_giveup_2
#	 | main_giveup_3
#	   -> main_giveup_common

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	sw	$s4, -28($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -28

	# save argc, argv
	add	$s0, $0, $a0
	add	$s1, $0, $a1

	# if (argc < 3) giveUp(argv[0],NULL);
	slti	$at, $s0, 4
	bne	$at, $0, main_giveup_0

	# length = intValue(argv[1]);
	addi	$a0, $s1, 4	# 1 * sizeof(word)
	lw	$a0, ($a0)	# (char *)$a0 = *(char **)$a0
	jal	intValue

	# if (length < 4 || length >= 40)
	#     giveUp(argv[0], "Invalid Length");
	# $at <- (length < 4) ? 1 : 0
	slti	$at, $v0, 4
	bne	$at, $0, main_giveup_1
	# $at <- (length < 40) ? 1 : 0
	slti	$at, $v0, 40
	beq	$at, $0, main_giveup_1
	# ... okay, save length
	add	$s2, $0, $v0

	# ntimes = intValue(argv[2]);
	addi	$a0, $s1, 8	# 2 * sizeof(word)
	lw	$a0, ($a0)
	jal	intValue

	# if (ntimes < 0 || ntimes >= 100)
	#     giveUp(argv[0], "Invalid # Iterations");
	# $at <- (ntimes < 0) ? 1 : 0
	slti	$at, $v0, 0
	bne	$at, $0, main_giveup_2
	# $at <- (ntimes < 100) ? 1 : 0
	slti	$at, $v0, 100
	beq	$at, $0, main_giveup_2
	# ... okay, save ntimes
	add	$s3, $0, $v0

main_seed:
	# seed = intValue(argv[3]);
	add	$a0, $s1, 12	# 3 * sizeof(word)
	lw	$a0, ($a0)
	jal	intValue

	# if (seed < 0) giveUp(argv[0], "Invalid Rand Seed");
	# $at <- (seed < 0) ? 1 : 0
	slt	$at, $v0, $0
	bne	$at, $0, main_giveup_3

main_seed_phi:
	add	$a0, $0, $v0
	jal	seedRand

	# start worm roughly in middle of grid

	# startCol: initial X-coord of head (X = column)
	# int startCol = 40/2 - length/2;
	addi	$s4, $0, 2
	addi	$a0, $0, 40
	div	$a0, $s4
	mflo	$a0
	# length/2
	div	$s2, $s4
	mflo	$s4
	# 40/2 - length/2
	sub	$a0, $a0, $s4

	# startRow: initial Y-coord of head (Y = row)
	# startRow = 20/2;
	addi	$s4, $0, 2
	addi	$a1, $0, 20
	div	$a1, $s4
	mflo	$a1

	# initWorm($a0=startCol, $a1=startRow, $a2=length)
	add	$a2, $0, $s2
	jal	initWorm

main_i_init:
	# int i = 0;
	add	$s4, $0, $0
main_i_cond:
	# i <= ntimes  ->  ntimes >= i  ->  !(ntimes < i)
	#   ->  $at <- (ntimes < i) ? 1 : 0
	slt	$at, $s3, $s4
	bne	$at, $0, main_i_end

	# clearGrid();
	jal	clearGrid

	# addWormToGrid($a0=length);
	add	$a0, $0, $s2
	jal	addWormToGrid

	# printf(CLEAR)
	la	$a0, main__clear
	addiu	$v0, $0, 4	# print_string
	syscall

	# printf("Iteration ")
	la	$a0, main__3
	addiu	$v0, $0, 4	# print_string
	syscall

	# printf("%d",i)
	add	$a0, $0, $s4
	addiu	$v0, $0, 1	# print_int
	syscall

	# putchar('\n')
	addi	$a0, $0, 0x0a
	addiu	$v0, $0, 11	# print_char
	syscall

	# drawGrid();
	jal	drawGrid

	# Debugging? print worm pos as (r1,c1) (r2,c2) ...

	# if (!moveWorm(length)) {...break}
	add	$a0, $0, $s2
	jal	moveWorm
	bne	$v0, $0, main_moveWorm_phi

	# printf("Blocked!\n")
	la	$a0, main__4
	addiu	$v0, $0, 4	# print_string
	syscall

	# break;
	j	main_i_end

main_moveWorm_phi:
	addi	$a0, $0, 1
	jal	delay

main_i_step:
	addi	$s4, $s4, 1
	j	main_i_cond
main_i_end:

	# exit (EXIT_SUCCESS)
	# ... let's return from main with `EXIT_SUCCESS' instead.
	addi	$v0, $0, 0	# EXIT_SUCCESS

main__post:
	# tear down stack frame
	lw	$s4, -24($fp)
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

main_giveup_0:
	add	$a1, $0, $0	# NULL
	j	main_giveup_common
main_giveup_1:
	la	$a1, main__0	# "Invalid Length"
	j	main_giveup_common
main_giveup_2:
	la	$a1, main__1	# "Invalid # Iterations"
	j	main_giveup_common
main_giveup_3:
	la	$a1, main__2	# "Invalid Rand Seed"
	# fall through
main_giveup_common:
	# giveUp ($a0=argv[0], $a1)
	lw	$a0, ($s1)	# argv[0]
	jal	giveUp		# never returns

####################################
# clearGrid() ... set all grid[][] elements to '.'
# .TEXT <clearGrid>
	.text
clearGrid:

# Frame:	$fp, $ra, $s0, $s1
# Uses: 	$s0, $s1, $t1, $t2, $t3, $t4, $t5
# Clobbers:	$t5

# Locals:
#	- `row' in $s0
#	- `col' in $s1
#	- `&grid[row][col]' in $t1
#	- '.' in $t2
#   - NROWS in $t3
#   - NCOLS in $t4
#   - temp in $t5

# Structure:
#   clearGrid
#   -> [prologue] 
#   -> clearGrid_outerloop_start
#       -> clearGrid_innerloop_start
#       -> clearGrid_innerloop_end
#   -> clearGrid_outerloop_end
#   -> [epilogue]
    
# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -16

### TODO: Your code goes here
	la    $t1, grid
	li    $t2, '.'	

	# for (int row = 0; row < NROWS; row++)
	li    $s0, 0								
	li    $t3, 20								

clearGrid_outerloop_start:
	bge   $s0, $t3, clearGrid_outerloop_end

	# for ( int col = 0; col < NCOLS; col++)		
	li    $s1, 0
	li    $t4, 40

clearGrid_innerloop_start:
	bge   $s1, $t4, clearGrid_innerloop_end

	# grid[row][col] = '.'
	mul   $t5, $s0, $t4						# $t5 = row * width of grid
	add   $t5, $t5, $s1						# $t5 += col
	add   $t5, $t5, $t1						# $t5 += &grid
	sb    $t2, ($t5)						

	addi  $s1, $s1, 1
	j     clearGrid_innerloop_start  

clearGrid_innerloop_end:
	addi  $s0, $s0, 1
	j     clearGrid_outerloop_start

clearGrid_outerloop_end:  

	# tear down stack frame
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# drawGrid() ... display current grid[][] matrix
# .TEXT <drawGrid>
	.text
drawGrid:

# Frame:	$fp, $ra, $s0, $s1, $t1
# Uses: 	$s0, $s1, $t1, $t3, $t4, $t5, $a0, $v0
# Clobbers:	$t5, $v0, $a0

# Locals:
#	- `row' in $s0
#	- `col' in $s1
#	- `&grid[row][col]' in $t1
#   - NROWS in $t3
#   - NCOLS in $t4
#   - temp in $t5

# Structure:
#   drawGrid
#   -> [prologue]
#   -> drawGrid_outerloop_start
#       -> drawGrid_innerloop_start
#       -> drawGrid_innerloop_end
#   -> drawGrid_outerloop_end
#   -> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -16

### TODO: Your code goes here
	la    $t1, grid

	# for (int row = 0; row < NROWS; row++)
	li    $s0, 0								
	li    $t3, 20								

drawGrid_outerloop_start:
	bge   $s0, $t3, drawGrid_outerloop_end
	# for ( int col = 0; col < NCOLS; col++)		
	li    $s1, 0
	li    $t4, 40

drawGrid_innerloop_start:
	bge   $s1, $t4, drawGrid_innerloop_end

	# $t5 = grid[row][col]
	mul   $t5, $s0, $t4						# $t5 = row * width of grid
	add   $t5, $t5, $s1						# $t5 += col
	add   $t5, $t5, $t1						# $t5 += &grid
	lb    $t5, ($t5)

	# print grid[row][col]
	add   $a0, $0, $t5
	li    $v0, 11							# print_char
	syscall 

	addi  $s1, $s1, 1
	j     drawGrid_innerloop_start  

drawGrid_innerloop_end:
	# print '\n'
	addi	$a0, $0, 0x0a
	li	    $v0, 11 						# print_char
	syscall

	addi  $s0, $s0, 1
	j     drawGrid_outerloop_start

drawGrid_outerloop_end:  
	
	# tear down stack frame
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# initWorm(col,row,len) ... set the wormCol[] and wormRow[]
#    arrays for a worm with head at (row,col) and body segements
#    on the same row and heading to the right (higher col values)
# .TEXT <initWorm>
	.text
initWorm:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $a2, $t0, $t1, $t2
# Clobbers:	$t0, $t1, $t2

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#	- `len' in $a2
#	- `newCol' in $t0
#	- `nsegs' in $t1
#	- temporary in $t2

# Structure
#   initWorm
#   -> [prologue]
#   -> initWorm_loop_start
#   -> initWorm_loop_end
#   -> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

### TODO: Your code goes here
	addi  $t0, $a0, 1						# newCol = col + 1
	
	sw    $a0, wormCol($0)					# wormCol[0] = col
	sw    $a1, wormRow($0)					# wormRow[0] = row

	# for (nsegs = 1; nsegs < len; nsegs++)
	li    $t1, 1

initWorm_loop_start:
	beq   $t1, $a2, initWorm_loop_end		

	# if (newCol == NCOLS) break
	li    $t2, 40
	beq   $t0, $t2, initWorm_loop_end

	# $t2 = nsegs*4
	li    $t2, 4
	mul   $t2, $t1, $t2
	
	# wormCol[nsegs] = newCol++
	sw    $t0, wormCol($t2)
	addi  $t0, $t0, 1

	# wormRow[nsegs] = row
	sw    $a1, wormRow($t2)

	addi  $t1, $t1, 1
	j     initWorm_loop_start

initWorm_loop_end:

	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# ongrid(col,row) ... checks whether (row,col)
#    is a valid coordinate for the grid[][] matrix
# .TEXT <onGrid>
	.text
onGrid:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $v0, $t0, $t1
# Clobbers:	$v0

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#   - NCOLS in $t0
#   - NROWS in $t1

# Structure
#   onGrid
#   -> [prologue]
#   -> onGrid_return0
#   -> onGrid_tearDown_stackframe
#   -> [epilogue]

# Code:

### TODO: complete this function

	# set up stack frame
	sw	  $fp, -4($sp)
	la    $fp, -4($sp)
	sw    $ra, -4($fp)
	addiu    $sp, $sp, -8

	li    $t0, 40
	li    $t1, 20
	
    # code for function
	bltz  $a0, onGrid_return0
	bge   $a0, $t0, onGrid_return0
	bltz  $a1, onGrid_return0
	bge   $a1, $t1, onGrid_return0

	# return 1
	li    $v0, 1
	j     onGrid_tearDown_stackframe

	# return 0
onGrid_return0:
	li    $v0, 0

onGrid_tearDown_stackframe:
	# tear down stack frame
	lw	  $ra, -4($fp)
	la    $sp, 4($fp)
	lw    $fp, ($fp)
	jr    $ra


####################################
# overlaps(r,c,len) ... checks whether (r,c) holds a body segment
# .TEXT <overlaps>
	.text
overlaps:

# Frame:	$fp, $ra
# Uses: 	$a0, $a1, $a2, $t6, $t0, $v0
# Clobbers:	$t6, $t0, $v0

# Locals:
#	- `col' in $a0
#	- `row' in $a1
#	- `len' in $a2
#	- `i' in $t6
#   - temp in $t0

# Structure:
#   overlaps
#   -> [prologue]
#   -> overlaps_loop_start
#       -> overlaps_loop_increment
#   -> overlaps_loops_end
#   -> overlaps_tearDown_stackFrame
#   -> [epilogue]

# Code:

### TODO: complete this function

	# set up stack frame
	sw    $fp, -4($sp)
	la    $fp, -4($sp)
	sw    $ra, -4($fp)
	addiu    $sp, $sp, -8

    # code for function
	# for (int i = 0; i < len; i++)
	li    $t6, 0

overlaps_loop_start:
	beq   $t6, $a2, overlaps_loop_end

	# if wormCol[i] != col continue
	li    $t0, 4
	mul   $t0, $t6, $t0
	lw    $t0, wormCol($t0)
	bne   $t0, $a0, overlaps_loop_increment

	# if wormRow[i] != row continue
	li    $t0, 4
	mul   $t0, $t6, $t0
	lw    $t0, wormRow($t0)
	bne   $t0, $a1, overlaps_loop_increment

	# return 1
	li    $v0, 1
	j     overlaps_tearDown_stackFrame

overlaps_loop_increment:
	addi  $t6, $t6, 1
	j     overlaps_loop_start

overlaps_loop_end:
	# return 0
	li    $v0, 0

overlaps_tearDown_stackFrame:
	# tear down stack frame
	lw    $ra, -4($fp)
	la    $sp, 4($fp)
	lw    $fp, ($fp)
	jr    $ra


####################################
# moveWorm() ... work out new location for head
#         and then move body segments to follow
# updates wormRow[] and wormCol[] arrays

# (col,row) coords of possible places for segments
# done as global data; putting on stack is too messy
	.data
	.align 4
possibleCol: .space 8 * 4	# sizeof(word)
possibleRow: .space 8 * 4	# sizeof(word)

# .TEXT <moveWorm>
	.text
moveWorm:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3, $s4, $s5, $s6, $s7
# Uses: 	$s0, $s1, $s2, $s3, $s4, $s5, $s6, $s7, $t0, $t1, $t2, $t3, $a0, $a1, $a2, $v0
# Clobbers:	$t0, $t1, $t2, $t3, $a0, $a1, $a2, $v0

# Locals:
#	- `col' in $s0
#	- `row' in $s1
#	- `len' in $s2
#	- `dx' in $s3
#	- `dy' in $s4
#	- `n' in $s7
#	- `i' in $t0
#	- tmp in $t1
#	- tmp in $t2
#	- tmp in $t3

# Structure:
#   moveWorm
#   -> [prologue]
#   -> moveWorm_outerloop_start
#       -> moveWorm_innerloop_start
#           -> moveWorm_innerloop_increment
#       -> moveWorm_innerloop_end
#   -> moveWorm_outerloop_end   
#   -> moveWorm_secondLoop_start
#   -> moveWorm_secondLoop_end
#   -> moveWorm_return0
#   -> moveWorm_tearDown_stackFrame
#   -> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	sw	$s4, -28($sp)
	sw	$s5, -32($sp)
	sw	$s6, -36($sp)
	sw	$s7, -40($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -40

### TODO: Your code goes here
	add   $s2, $a0, $0 						# $s2 = len
	li    $s7, 0 							# n = 0

	# for (int dx = -1; dx <= 1; dx++)
	li    $s3, -1							# dx = -1

moveWorm_outerloop_start:
	li    $t1, 1	
	bgt   $s3, $t1, moveWorm_outerloop_end

	# for (int dy = -1; dy <= 1; dy++)
	li    $s4, -1

moveWorm_innerloop_start:
	li    $t1, 1
	bgt   $s4, $t1, moveWorm_innerloop_end

	# col = wormCol[0] + dx
	lw    $t2, wormCol($0)
	add   $s0, $t2, $s3

	# row = wormRow[0] + dy
	lw    $t2, wormRow($0)
	add   $s1, $t2, $s4

	# if onGrid(col,row) == 0, dy++
	add   $a0, $s0, $0
	add   $a1, $s1, $0
	jal   onGrid
	beqz  $v0, moveWorm_innerloop_increment

	# if overlaps(col,row,len) == 1, dy++
	add   $a0, $s0, $0
	add   $a1, $s1, $0
	add   $a2, $s2, $0
	jal   overlaps
	li    $t1, 1
	beq   $v0, $t1, moveWorm_innerloop_increment

	# possibleCol[n] = col && possibleRow[n] = row
	li    $t2, 4
	mul   $t2, $s7, $t2
	sw    $s0, possibleCol($t2)
	sw    $s1, possibleRow($t2)

	addi  $s7, $s7, 1						# n++

moveWorm_innerloop_increment:
	addi  $s4, $s4, 1
	j     moveWorm_innerloop_start

moveWorm_innerloop_end:
	addi  $s3, $s3, 1
	j     moveWorm_outerloop_start

moveWorm_outerloop_end:
	beqz  $s7, moveWorm_return0				# if (n == 0) return 0

	# for (int i = len - 1; i > 0; i--)	
	addi  $t0, $s2, -1	

moveWorm_secondLoop_start:
	beqz  $t0, moveWorm_secondLoop_end

	li    $t2, 4
	mul   $t2, $t0, $t2						# $t2 = i*4
	addi  $t3, $t2, -4 						# $t3 = i*4 - 4

	# wormRow[i] = wormRow[i-1]
	lw    $t1, wormRow($t3)
	sw    $t1, wormRow($t2)

	# wormCol[i] = wormCol[i-1]
	lw    $t1, wormCol($t3)
	sw    $t1, wormCol($t2)

	addi  $t0, $t0, -1
	j     moveWorm_secondLoop_start

moveWorm_secondLoop_end:
	# i = randValue(n)
	add   $a0, $0, $s7
	jal   randValue
	add   $t0, $0, $v0

	# wormRow[0] = possibleRow[i]
	li    $t1, 4
	mul   $t0, $t0, $t1
	lw    $t1, possibleRow($t0)
	sw    $t1, wormRow($0)

	# wormCol[0] = possibleCol[i]
	lw    $t1, possibleCol($t0)
	sw    $t1, wormCol($0)

	# return 1
	li    $v0, 1
	j     moveWorm_tearDown_stackFrame

	# return 0
moveWorm_return0:
	li    $v0, 0
	j     moveWorm_tearDown_stackFrame

moveWorm_tearDown_stackFrame:
	# tear down stack frame
	lw	$s7, -36($fp)
	lw	$s6, -32($fp)
	lw	$s5, -28($fp)
	lw	$s4, -24($fp)
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)

	jr	$ra

####################################
# addWormTogrid(N) ... add N worm segments to grid[][] matrix
#    0'th segment is head, located at (wormRow[0],wormCol[0])
#    i'th segment located at (wormRow[i],wormCol[i]), for i > 0
# .TEXT <addWormToGrid>
	.text
addWormToGrid:

# Frame:	$fp, $ra, $s0, $s1, $s2, $s3
# Uses: 	$a0, $s0, $s1, $s2, $s3, $t0, $t1, $t2, $t3, $t4, $t5
# Clobbers:	$t1, $t0

# Locals:
#	- `len' in $a0
#	- 'col' in $s0
#	- 'row' in $s1
#	- `grid[row][col]' in $s2
#	- `i' in $t0
#   - '@' in $t3
#   - 'o' in $t4
#   -  NCOLS in $t5
#   -  temp in $t1

# Structure
#   addWormToGrid
#   -> [prologue]
#   -> addWormToGrid_loop_start
#   -> addWormToGrid_loop_end
#   -> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	sw	$s0, -12($sp)
	sw	$s1, -16($sp)
	sw	$s2, -20($sp)
	sw	$s3, -24($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -24

### TODO: your code goes here
	li    $t3, '@'
	li    $t4, 'o'
	li    $t5, 40

	la    $s2, grid         

	lw    $s1, wormRow($0)        			# row = wormRow[0]
	lw    $s0, wormCol($0)        			# col = wormCol[0]

	# grid[row][col] = '@'
	mul   $t1, $s1, $t5      				# t1 = row * width of grid
	add   $t1, $t1, $s0      				# t1 += col
	add   $t1, $t1, $s2      				# t1 += 1st address of grid[row][col]
	sb    $t3, ($t1)        				

	# for (int i = 1; i < len; i++)
	li    $t0, 1			

addWormToGrid_loop_start:
	beq   $t0, $a0, addWormToGrid_loop_end
	
	# row = wormRow[i] & col = wormCol[i]
	li    $t1, 4
	mul   $t1, $t0, $t1         	   	
	lw    $s1, wormRow($t1)        	        
	lw    $s0, wormCol($t1)        		  

	# grid[row][col] = 'o' 
	mul   $t1, $s1, $t5                     # t1 = row * width of grid
	add   $t1, $t1, $s0                     # t1 += col
	add   $t1, $t1, $s2                     # t1 += 1st address of grid[row][col]
	sb    $t4, ($t1)             			

	addi  $t0, $t0, 1 
	j     addWormToGrid_loop_start

addWormToGrid_loop_end:

	# tear down stack frame
	lw	$s3, -20($fp)
	lw	$s2, -16($fp)
	lw	$s1, -12($fp)
	lw	$s0, -8($fp)
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# giveUp(msg) ... print error message and exit
# .TEXT <giveUp>
	.text
giveUp:

# Frame:	frameless; divergent
# Uses: 	$a0, $a1
# Clobbers:	$s0, $s1

# Locals:
#	- `progName' in $a0/$s0
#	- `errmsg' in $a1/$s1

# Code:
	add	$s0, $0, $a0
	add	$s1, $0, $a1

	# if (errmsg != NULL) printf("%s\n",errmsg);
	beq	$s1, $0, giveUp_usage

	# puts $a0
	add	$a0, $0, $s1
	addiu	$v0, $0, 4	# print_string
	syscall

	# putchar '\n'
	add	$a0, $0, 0x0a
	addiu	$v0, $0, 11	# print_char
	syscall

giveUp_usage:
	# printf("Usage: %s #Segments #Moves Seed\n", progName);
	la	$a0, giveUp__0
	addiu	$v0, $0, 4	# print_string
	syscall

	add	$a0, $0, $s0
	addiu	$v0, $0, 4	# print_string
	syscall

	la	$a0, giveUp__1
	addiu	$v0, $0, 4	# print_string
	syscall

	# exit(EXIT_FAILURE);
	addi	$a0, $0, 1 # EXIT_FAILURE
	addiu	$v0, $0, 17	# exit2
	syscall
	# doesn't return

####################################
# intValue(str) ... convert string of digits to int value
# .TEXT <intValue>
	.text
intValue:

# Frame:	$fp, $ra
# Uses: 	$t0, $t1, $t2, $t3, $t4, $t5
# Clobbers:	$t0, $t1, $t2, $t3, $t4, $t5

# Locals:
#	- `s' in $t0
#	- `*s' in $t1
#	- `val' in $v0
#	- various temporaries in $t2

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# int val = 0;
	add	$v0, $0, $0

	# register various useful values
	addi	$t2, $0, 0x20 # ' '
	addi	$t3, $0, 0x30 # '0'
	addi	$t4, $0, 0x39 # '9'
	addi	$t5, $0, 10

	# for (char *s = str; *s != '\0'; s++) {
intValue_s_init:
	# char *s = str;
	add	$t0, $0, $a0
intValue_s_cond:
	# *s != '\0'
	lb	$t1, ($t0)
	beq	$t1, $0, intValue_s_end

	# if (*s == ' ') continue; # ignore spaces
	beq	$t1, $t2, intValue_s_step

	# if (*s < '0' || *s > '9') return -1;
	blt	$t1, $t3, intValue_isndigit
	bgt	$t1, $t4, intValue_isndigit

	# val = val * 10
	mult	$v0, $t5
	mflo	$v0

	# val = val + (*s - '0');
	sub	$t1, $t1, $t3
	add	$v0, $v0, $t1

intValue_s_step:
	# s = s + 1
	addi	$t0, $t0, 1	# sizeof(byte)
	j	intValue_s_cond
intValue_s_end:

intValue__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

intValue_isndigit:
	# return -1
	addi	$v0, $0, -1
	j	intValue__post

####################################
# delay(N) ... waste some time; larger N wastes more time
#                            makes the animation believable
# .TEXT <delay>
	.text
delay:

# Frame:	$fp, $ra
# Uses: 	$a0, $t0, $t1, $t2, $t3, $t4, $t5, $t6
# Clobbers:	$t0, $t1, $t2, $t6

# Locals:
#	- `n' in $a0
#	- `x' in $t6
#	- `i' in $t0
#	- `j' in $t1
#	- `k' in $t2
#	- 425 in $t3
#   - 75 in $t4
#	- temp in $t5

# Structure
#   delay
#   -> [prologue]
#   -> delay_outerloop_start
#       -> delay_innerloop1_start
#           -> delay_innerloop2_start
#           -> delay_innerloop2_end
#       -> delay_innerloop1_end
#   -> delay_outerloop_end
#   -> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

### TODO: your code goes here
	li    $t6, 3 							# x = 3
	li    $t3, 425
	li    $t4, 75

	# for (int i = 0; i < n; i++)
	li    $t0, 0

delay_outerloop_start:
	bge   $t0, $a0, delay_outerloop_end

	# for (int j = 0; j < 425; i++)
	li    $t1, 0

delay_innerloop1_start:
	bge   $t1, $t3, delay_innerloop1_end

	# for (int k = 0; k < 75; k++)
	li    $t2, 0

delay_innerloop2_start:
	bge   $t2, $t4, delay_innerloop2_end

	# x *= 3
	li    $t5, 3
	mul   $t6, $t6, $t5

	addi  $t2, $t2, 1
	j     delay_innerloop2_start

delay_innerloop2_end:
	addi  $t1, $t1, 1
	j     delay_innerloop1_start

delay_innerloop1_end:
	addi  $t0, $t0, 1
	j     delay_outerloop_start

delay_outerloop_end:

	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra


####################################
# seedRand(Seed) ... seed the random number generator
# .TEXT <seedRand>
	.text
seedRand:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	[none]

# Locals:
#	- `seed' in $a0

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# randSeed <- $a0
	sw	$a0, randSeed

seedRand__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

####################################
# randValue(n) ... generate random value in range 0..n-1
# .TEXT <randValue>
	.text
randValue:

# Frame:	$fp, $ra
# Uses: 	$a0
# Clobbers:	$t0, $t1

# Locals:	[none]
#	- `n' in $a0

# Structure:
#	rand
#	-> [prologue]
#       no intermediate control structures
#	-> [epilogue]

# Code:
	# set up stack frame
	sw	$fp, -4($sp)
	sw	$ra, -8($sp)
	la	$fp, -4($sp)
	addiu	$sp, $sp, -8

	# $t0 <- randSeed
	lw	$t0, randSeed
	# $t1 <- 1103515245 (magic)
	li	$t1, 0x41c64e6d

	# $t0 <- randSeed * 1103515245
	mult	$t0, $t1
	mflo	$t0

	# $t0 <- $t0 + 12345 (more magic)
	addi	$t0, $t0, 0x3039

	# $t0 <- $t0 & RAND_MAX
	and	$t0, $t0, 0x7fffffff

	# randSeed <- $t0
	sw	$t0, randSeed

	# return (randSeed % n)
	div	$t0, $a0
	mfhi	$v0

rand__post:
	# tear down stack frame
	lw	$ra, -4($fp)
	la	$sp, 4($fp)
	lw	$fp, ($fp)
	jr	$ra

