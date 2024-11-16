.data
    # File related
    filename:       .asciiz "input_matrix.txt"
    buffer:         .space 1024
    newline:        .asciiz "\n"
    space:          .asciiz " "
    
    # Debug messages
    error_msg:      .asciiz "Error opening file\n"
    error_params:    .asciiz "Invalid parameters"
    error_size:      .asciiz "Convolution not possible: image too small"
    error_stride:    .asciiz "Convolution not possible: stride too large"

    # Required variables as per specification
    image:          .word 0    # Will store pointer to image matrix
    kernel:         .word 0    # Will store pointer to kernel matrix
    out:            .word 0    # Will store pointer to output matrix

    # Constants for float operations
    float_zero:     .float 0.0
    float_ten:      .float 10.0
    float_one:      .float 1.0
    float_point_one: .float 0.1
    float_hundred: .float 100.0
    float_thousand: .float 1000.0

    # Variables to store matrix dimensions
    N:             .word 0    # Image matrix size
    M:             .word 0    # Kernel matrix size
    padding:       .word 0    # Padding value
    stride:        .word 0    # Stride value
    
    # File output
    outfile:        .asciiz "output_matrix.txt"
    minus:    .asciiz "-"
    point:    .asciiz "."
    digit:    .space 2     # Space for single digit + null terminator
    temp:           .float 0.0     # Temporary float storage
    temp_str:       .space 32      # Temp buffer for number conversion
    

    # Variables for padded matrix
    padded_size:    .word 0    # N + 2*padding
    padded:         .word 0    # Pointer to padded matrix
    out_size:       .word 0    # Output matrix size: ((N + 2*p - M)/stride) + 1

.text
.globl main

main:
    # Open file
    li   $v0, 13          # System call for open file
    la   $a0, filename    # Load filename
    li   $a1, 0           # Flag for reading
    li   $a2, 0           # Mode is ignored
    syscall
    
    # Check for errors
    bltz $v0, file_error
    move $s0, $v0         # Save file descriptor

    # Read file into buffer
    li   $v0, 14          # System call for read file
    move $a0, $s0         # File descriptor
    la   $a1, buffer      # Buffer to read into
    li   $a2, 1024        # Maximum number of characters to read
    syscall

    # Close the file
    li   $v0, 16          # System call for close file
    move $a0, $s0         # File descriptor to close
    syscall

    # Process first line (N M p s)
    la   $s0, buffer      # Buffer address
    
    # Read N
    jal  read_int
    sw   $v0, N          # Store N

    # Read M
    jal  read_int
    sw   $v0, M          # Store M

    # Read padding
    jal  read_int
    sw   $v0, padding    # Store padding

    # Read stride
    jal  read_int
    sw   $v0, stride     # Store stride
    
# Add this code after reading parameters (after reading stride)
validate_params:
    # Check N (3 <= N <= 7)
    lw   $t0, N
    li   $t1, 3
    blt  $t0, $t1, invalid_params  # if N < 3
    li   $t1, 7
    bgt  $t0, $t1, invalid_params  # if N > 7

    # Check M (2 <= M <= 4)
    lw   $t0, M
    li   $t1, 2
    blt  $t0, $t1, invalid_params  # if M < 2
    li   $t1, 4
    bgt  $t0, $t1, invalid_params  # if M > 4

    # Check padding (0 <= p <= 4)
    lw   $t0, padding
    bltz $t0, invalid_params       # if p < 0
    li   $t1, 4
    bgt  $t0, $t1, invalid_params  # if p > 4

    # Check stride (1 <= s <= 3)
    lw   $t0, stride
    li   $t1, 1
    blt  $t0, $t1, invalid_params  # if s < 1
    li   $t1, 3
    bgt  $t0, $t1, invalid_params  # if s > 3

    # Calculate padded size
    lw   $t0, N           # Load N
    lw   $t1, padding     # Load p
    add  $t2, $t0, $t1    # N + p
    add  $t2, $t2, $t1    # N + 2p
    sw   $t2, padded_size # Store padded_size

    # Check if padded size is sufficient for kernel
    lw   $t0, padded_size
    lw   $t1, M
    blt  $t0, $t1, size_error  # if padded_size < M

    # Calculate output size and check if valid
    lw   $t0, padded_size  # Load padded size
    lw   $t1, M           # Load kernel size
    sub  $t2, $t0, $t1    # padded_size - M
    lw   $t3, stride
    div  $t2, $t3         # (padded_size - M) / stride
    mflo $t2
    addi $t2, $t2, 1      # ((padded_size - M) / stride) + 1
    
    # Check if output size is valid (should be > 0)
    blez $t2, stride_error
    
    # Store output size if valid
    sw   $t2, out_size
    
    j    continue_program   # All checks passed

invalid_params:
    # Open output file
    li   $v0, 13
    la   $a0, outfile
    li   $a1, 1            # Write mode
    li   $a2, 0
    syscall
    move $s6, $v0

    # Write error message
    li   $v0, 15
    move $a0, $s6
    la   $a1, error_params
    li   $a2, 17           # Length of "Invalid parameters"
    syscall

    # Close file
    li   $v0, 16
    move $a0, $s6
    syscall

    j    exit

size_error:
    # Open output file
    li   $v0, 13
    la   $a0, outfile
    li   $a1, 1
    li   $a2, 0
    syscall
    move $s6, $v0

    # Write error message
    li   $v0, 15
    move $a0, $s6
    la   $a1, error_size
    li   $a2, 41          # Length of error message
    syscall

    # Close file
    li   $v0, 16
    move $a0, $s6
    syscall

    j    exit

stride_error:
    # Open output file
    li   $v0, 13
    la   $a0, outfile
    li   $a1, 1
    li   $a2, 0
    syscall
    move $s6, $v0

    # Write error message
    li   $v0, 15
    move $a0, $s6
    la   $a1, error_stride
    li   $a2, 42          # Length of error message
    syscall

    # Close file
    li   $v0, 16
    move $a0, $s6
    syscall

    j    exit

continue_program:
    # Allocate memory for matrices
    # For image matrix: N*N*4 bytes (4 bytes per float)
    lw   $t0, N
    mul  $t1, $t0, $t0   # N*N
    sll  $a0, $t1, 2     # Multiply by 4 for bytes
    li   $v0, 9          # sbrk syscall
    syscall
    sw   $v0, image      # Store pointer to image matrix

    # For kernel matrix: M*M*4 bytes
    lw   $t0, M
    mul  $t1, $t0, $t0   # M*M
    sll  $a0, $t1, 2     # Multiply by 4 for bytes
    li   $v0, 9          # sbrk syscall
    syscall
    sw   $v0, kernel     # Store pointer to kernel matrix

    # For output matrix: Calculate size based on convolution formula
    # Output size = ((N - M + 2P)/S) + 1, where P is padding and S is stride
    # We'll allocate maximum possible size for simplicity: N*N*4 bytes
    lw   $t0, N
    mul  $t1, $t0, $t0   # N*N
    sll  $a0, $t1, 2     # Multiply by 4 for bytes
    li   $v0, 9          # sbrk syscall
    syscall
    sw   $v0, out        # Store pointer to output matrix

    # Read image matrix
    lw   $t0, N          # Load N
    mul  $t1, $t0, $t0   # Calculate total elements (N*N)
    lw   $t2, image      # Load image array address
    
read_image_loop:
    beqz $t1, read_image_done
    jal  read_float
    swc1 $f0, ($t2)      # Store float in image array
    
    addi $t2, $t2, 4     # Move to next float position
    addi $t1, $t1, -1    # Decrement counter
    j    read_image_loop
    
read_image_done:
    # Read kernel matrix
    lw   $t0, M          # Load M
    mul  $t1, $t0, $t0   # Calculate total elements (M*M)
    lw   $t2, kernel     # Load kernel array address
    
read_kernel_loop:
    beqz $t1, read_kernel_done
    jal  read_float
    swc1 $f0, ($t2)      # Store float in kernel array
    
    # Print the float
    # lwc1 $f12, ($t2)
    # li   $v0, 2
    # syscall
    # la   $a0, space
    # li   $v0, 4
    # syscall
    
    addi $t2, $t2, 4     # Move to next float position
    addi $t1, $t1, -1    # Decrement counter
    j    read_kernel_loop

read_kernel_done:
    # Print newline for better readability in console
    # la   $a0, newline
    # li   $v0, 4
    # syscall

    # Calculate padded size and output size
    lw   $t0, N           # Load original matrix size
    lw   $t1, padding     # Load padding value
    add  $t2, $t0, $t1    # N + p
    add  $t2, $t2, $t1    # N + 2p (padded size)
    sw   $t2, padded_size

    # Calculate output size: ((N + 2*p - M)/stride) + 1
    lw   $t0, N           # Load N
    lw   $t1, padding     # Load p
    lw   $t2, M           # Load M
    lw   $t3, stride      # Load stride
    add  $t4, $t0, $t1    # N + p
    add  $t4, $t4, $t1    # N + 2p
    sub  $t4, $t4, $t2    # (N + 2p - M)
    div  $t4, $t3         # Divide by stride
    mflo $t4              # Get quotient
    addi $t4, $t4, 1      # Add 1
    sw   $t4, out_size    # Store output size

    # Allocate memory for padded matrix
    lw   $t0, padded_size  # Load padded size
    mul  $t1, $t0, $t0     # Calculate total elements
    sll  $a0, $t1, 2       # Multiply by 4 for bytes
    li   $v0, 9            # sbrk syscall
    syscall
    sw   $v0, padded       # Store padded matrix pointer

    # Zero out padded matrix
    lw   $t0, padded       # Load padded matrix address
    lw   $t1, padded_size  # Load padded size
    mul  $t1, $t1, $t1     # Total elements
    l.s  $f0, float_zero   # Load 0.0
    
padding_zero_loop:
    beqz $t1, copy_input
    swc1 $f0, ($t0)        # Store 0.0
    addi $t0, $t0, 4       # Next element
    addi $t1, $t1, -1      # Decrement counter
    j    padding_zero_loop

    # Copy input matrix to padded matrix
copy_input:
    lw   $t0, N            # Original size
    lw   $t1, padding      # Padding size
    lw   $t2, padded_size  # Padded matrix size
    lw   $s0, image        # Source matrix
    lw   $s1, padded       # Destination matrix
    
    # Loop through each element of original matrix
    li   $t3, 0            # Row counter
copy_row_loop:
    beq  $t3, $t0, prepare_convolution
    li   $t4, 0            # Column counter
copy_col_loop:
    beq  $t4, $t0, next_row

    # Calculate source index
    mul  $t5, $t3, $t0     # row * N
    add  $t5, $t5, $t4     # + col
    sll  $t5, $t5, 2       # * 4 bytes
    add  $t5, $t5, $s0     # Add base address

    # Calculate destination index
    add  $t6, $t3, $t1     # row + padding
    mul  $t6, $t6, $t2     # * padded_size
    add  $t6, $t6, $t4     # + col
    add  $t6, $t6, $t1     # + padding
    sll  $t6, $t6, 2       # * 4 bytes
    add  $t6, $t6, $s1     # Add base address

    # Copy value
    lwc1 $f0, ($t5)
    swc1 $f0, ($t6)

    addi $t4, $t4, 1       # Next column
    j    copy_col_loop

next_row:
    addi $t3, $t3, 1       # Next row
    j    copy_row_loop

prepare_convolution:
    # Prepare output matrix size and pointers
    lw   $s0, padded       # Padded matrix base address
    lw   $s1, kernel       # Kernel matrix base address
    lw   $s2, out          # Output matrix base address
    lw   $s3, padded_size  # Size of padded matrix
    lw   $s4, M            # Size of kernel
    lw   $s5, stride       # Stride value
    lw   $s6, out_size     # Output size
    
    # Initialize outer loop counters
    li   $t8, 0            # Row counter for output matrix

outer_loop:
    beq  $t8, $s6, write_output  # If done with all rows, go to write output
    li   $t9, 0            # Column counter for output matrix

inner_loop:
    beq  $t9, $s6, next_output_row  # If done with current row
    
    # Calculate starting position in padded matrix
    mul  $t0, $t8, $s5     # output_row * stride
    mul  $t1, $t9, $s5     # output_col * stride
    
    # Initialize convolution sum
    l.s  $f0, float_zero   # sum = 0.0
    
    # Kernel row loop
    li   $t2, 0            # Kernel row counter

kernel_row:
    beq  $t2, $s4, store_output   # If done with kernel
    li   $t3, 0            # Kernel column counter

kernel_col:
    beq  $t3, $s4, next_kernel_row
    
    # Calculate indices for padded and kernel matrices
    add  $t4, $t0, $t2     # (output_row * stride) + kernel_row
    mul  $t4, $t4, $s3     # * padded_size
    add  $t4, $t4, $t1     # + (output_col * stride)
    add  $t4, $t4, $t3     # + kernel_col
    sll  $t4, $t4, 2       # * 4 bytes
    add  $t4, $t4, $s0     # Add padded matrix base
    
    mul  $t5, $t2, $s4     # kernel_row * kernel_size
    add  $t5, $t5, $t3     # + kernel_col
    sll  $t5, $t5, 2       # * 4 bytes
    add  $t5, $t5, $s1     # Add kernel base
    
    # Perform multiplication and addition
    lwc1 $f1, ($t4)        # Load padded value
    lwc1 $f2, ($t5)        # Load kernel value
    mul.s $f1, $f1, $f2    # Multiply values
    add.s $f0, $f0, $f1    # Add to sum
    
    addi $t3, $t3, 1       # Next kernel column
    j    kernel_col

next_kernel_row:
    addi $t2, $t2, 1       # Next kernel row
    j    kernel_row

store_output:
    # Calculate position in output matrix
    mul  $t0, $t8, $s6     # output_row * output_size
    add  $t0, $t0, $t9     # + output_col
    sll  $t0, $t0, 2       # * 4 bytes
    add  $t0, $t0, $s2     # Add output base address
    swc1 $f0, ($t0)        # Store result in output matrix
    
    addi $t9, $t9, 1       # Next output column
    j    inner_loop

next_output_row:
    addi $t8, $t8, 1       # Next output row
    j    outer_loop

write_output:
    # Initialize buffer pointer and output matrix pointer
    la   $s7, buffer       # Buffer pointer
    lw   $s0, out          # Output matrix pointer
    lw   $t0, out_size     # Output matrix size
    mul  $t1, $t0, $t0     # Total elements
    li   $t2, 0            # Counter

write_loop:
    beq  $t2, $t1, write_file    # If all elements processed, write to file
    
    # Load current float
    lwc1 $f12, ($s0)
    
    # Check if zero
    mtc1  $zero, $f0
    c.eq.s $f12, $f0
    bc1t   write_zero
    
    # Check if negative
    c.lt.s $f12, $f0
    bc1f   write_positive
    
    # Write minus sign for negative numbers
    li   $t4, '-'
    sb   $t4, ($s7)
    addi $s7, $s7, 1
    neg.s $f12, $f12      # Make positive for processing

write_positive:
    cvt.w.s $f0, $f12         # Convert to integer
    mfc1 $t4, $f0             # Move to integer register
    mtc1 $t4, $f0
    cvt.s.w $f0, $f0
    sub.s $f1, $f12, $f0      # Get decimal part
    
    # Convert integer to string
    abs  $t4, $t4             # Get absolute value
    li   $t5, 100             # For handling numbers up to 999
    div  $t4, $t5
    mflo $t6                  # Hundreds
    mfhi $t7                  # Remainder
    
    # Write hundreds if present
    beqz $t6, tens
    addi $t6, $t6, 48
    sb   $t6, ($s7)
    addi $s7, $s7, 1

tens:
    li   $t5, 10
    div  $t7, $t5
    mflo $t6                  # Tens
    mfhi $t7                  # Ones
    
    beqz $t6, ones
    addi $t6, $t6, 48
    sb   $t6, ($s7)
    addi $s7, $s7, 1

ones:
    addi $t7, $t7, 48
    sb   $t7, ($s7)
    addi $s7, $s7, 1
    
    # Write decimal point
    li   $t4, '.'
    sb   $t4, ($s7)
    addi $s7, $s7, 1
    
    # Convert decimal part
    l.s   $f2, float_ten      # Load 10.0
    li    $t4, 0              # Digit counter

write_decimal_loop:
    beq   $t4, 4, finish_decimal  # Write exactly 4 decimal places
    mul.s $f1, $f1, $f2          # Multiply by 10
    cvt.w.s $f3, $f1             # Get integer part
    mfc1  $t5, $f3
    
    abs   $t5, $t5               
    li    $t6, 10
    div   $t5, $t6               
    mfhi  $t5                    
    addi  $t5, $t5, 48          
    sb    $t5, ($s7)            
    addi  $s7, $s7, 1
    
    addi  $t5, $t5, -48         
    mtc1  $t5, $f3
    cvt.s.w $f3, $f3            
    sub.s $f1, $f1, $f3         
    
    addi  $t4, $t4, 1           
    j     write_decimal_loop

finish_decimal:
    j     add_space

write_zero:
    # Write "0.0000"
    li   $t4, '0'
    sb   $t4, ($s7)
    addi $s7, $s7, 1
    li   $t4, '.'
    sb   $t4, ($s7)
    addi $s7, $s7, 1
    li   $t4, 4           # Write 4 zeros
write_zero_loop:
    beqz $t4, add_space
    li   $t5, '0'
    sb   $t5, ($s7)
    addi $s7, $s7, 1
    addi $t4, $t4, -1
    j    write_zero_loop

add_space:
    # Add space if not last element
    addi $t2, $t2, 1       # Increment counter
    beq  $t2, $t1, next_num
    li   $t4, ' '
    sb   $t4, ($s7)
    addi $s7, $s7, 1

next_num:
    addi $s0, $s0, 4       # Move to next float
    j    write_loop
write_file:
    # Add newline at the end of buffer
    li   $t4, '\n'
    sb   $t4, ($s7)
    addi $s7, $s7, 1
    
    # Calculate buffer length
    la   $t0, buffer       # Start of buffer
    sub  $t1, $s7, $t0     # End - Start = Length
    
    # Open output file
    li   $v0, 13           # Open file syscall
    la   $a0, outfile      # Output filename
    li   $a1, 1            # Open for writing (flags are 1)
    li   $a2, 0            # Mode is ignored
    syscall
    move $s6, $v0          # Save file descriptor
    
    # Check for errors
    bltz $s6, file_error
    
    # Write to file
    li   $v0, 15           # Write file syscall
    move $a0, $s6          # File descriptor
    la   $a1, buffer       # Buffer
    move $a2, $t1          # Length
    syscall
    
    # Close file
    li   $v0, 16           # Close file syscall
    move $a0, $s6
    syscall
    
    j    exit              # Exit program when done writing
exit:
    li   $v0, 10          # Exit program
    syscall
    
# Error handling
file_error:
    la   $a0, error_msg
    li   $v0, 4
    syscall
    li   $v0, 10
    syscall

# Function to read integer from buffer
read_int:
    li   $v0, 0          # Initialize result
    li   $t6, 0          # Flag for negative numbers
read_int_loop:
    lb   $t0, ($s0)      # Load character
    
    # Check for negative sign
    bne  $t0, 45, not_negative  # if not '-'
    li   $t6, 1          # Set negative flag
    addi $s0, $s0, 1     # Move to next character
    j    read_int_loop
    
not_negative:
    # Check for space, newline, or null terminator
    beq  $t0, 32, read_int_done  # Space
    beq  $t0, 10, read_int_done  # Newline (LF)
    beq  $t0, 13, read_int_cr    # Carriage return (CR)
    beq  $t0, 0, read_int_done   # Null terminator
    
    # Convert character to integer and add to result
    addi $t0, $t0, -48   # Convert ASCII to integer
    bltz $t0, read_int_done   # If not a digit, we're done
    bgt  $t0, 9, read_int_done
    mul  $v0, $v0, 10    # Multiply current result by 10
    add  $v0, $v0, $t0   # Add new digit
    
    addi $s0, $s0, 1     # Move to next character
    j    read_int_loop

read_int_cr:
    addi $s0, $s0, 2     # Skip both CR and LF
    j    read_int_finish

read_int_done:
    addi $s0, $s0, 1     # Skip delimiter

read_int_finish:
    # Apply negative sign if needed
    beqz $t6, read_int_return
    neg  $v0, $v0
read_int_return:
    jr   $ra

# Modified read_float function to handle line endings better
read_float:
    # Initialize variables
    l.s   $f0, float_zero     # Result
    l.s   $f2, float_ten      # Constant 10.0
    li    $t4, 0              # Sign flag (0 = positive, 1 = negative)
    li    $t5, 0              # Decimal flag (0 = before decimal, 1 = after)
    l.s   $f4, float_one      # Decimal position

read_float_loop:
    lb    $t0, ($s0)          # Load character
    
    # Check for special characters
    beq   $t0, 32, read_float_done  # Space
    beq   $t0, 10, read_float_done  # Newline (LF)
    beq   $t0, 13, read_float_cr    # Carriage return (CR)
    beq   $t0, 0, read_float_done   # Null terminator
    
    # Check for negative sign
    beq   $t0, 45, set_negative     # Minus sign
    
    # Check for decimal point
    beq   $t0, 46, set_decimal      # Decimal point
    
    # Convert character to float and add to result
    addi  $t0, $t0, -48        # Convert ASCII to integer
    bltz  $t0, read_float_done  # If not a digit, we're done
    bgt   $t0, 9, read_float_done
    mtc1  $t0, $f6
    cvt.s.w $f6, $f6          # Convert to float
    
    beqz  $t5, before_decimal  # If before decimal point
    
    # After decimal point
    mul.s $f6, $f6, $f4       # Multiply by decimal position
    add.s $f0, $f0, $f6       # Add to result
    div.s $f4, $f4, $f2       # Move decimal position
    j     read_float_next
    
before_decimal:
    mul.s $f0, $f0, $f2       # Multiply current result by 10
    add.s $f0, $f0, $f6       # Add new digit
    
read_float_next:
    addi  $s0, $s0, 1         # Move to next character
    j     read_float_loop

read_float_cr:
    addi  $s0, $s0, 2         # Skip both CR and LF
    j     read_float_finish

read_float_done:
    addi  $s0, $s0, 1         # Skip delimiter

read_float_finish:
    beqz  $t4, read_float_return    # If positive, skip negation
    neg.s $f0, $f0            # Negate result if negative
read_float_return:
    jr    $ra

set_negative:
    li    $t4, 1              # Set negative flag
    addi  $s0, $s0, 1         # Move to next character
    j     read_float_loop

set_decimal:
    li    $t5, 1              # Set decimal flag
    l.s   $f4, float_point_one  # Initialize decimal position
    addi  $s0, $s0, 1         # Move to next character
    j     read_float_loop

skip_negate:
    addi  $s0, $s0, 1         # Skip delimiter
    jr    $ra
