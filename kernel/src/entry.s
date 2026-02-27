.attribute arch, "rv64gc"
.section .text.boot
.globl _start

_start:
    # clear the global pointer to prevent clang from assuming it can use gp relative addressing before we like set it up
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # set up the stack pointer
    la sp, stack_top


    # jump to kmain
    call kmain

    # hang otherwise it will loop forever
.hang:
    wfi
    j .hang

.section .bss
.align 16
stack_bottom:
    .space 16384 # 16K
stack_top: