.section .data
.align 3

fmt_buf:
    .space 32

.section .text
.globl serial_init
.globl serial_putc
.globl serial_puts
.globl printk

.equ UART_BASE,     0x10000000
.equ UART_THR,      0x00
.equ UART_RBR,      0x00
.equ UART_IER,      0x01
.equ UART_FCR,      0x02
.equ UART_LCR,      0x03
.equ UART_MCR,      0x04
.equ UART_LSR,      0x05
.equ UART_LSR_THRE, 0x20
.equ UART_LCR_DLAB, 0x80
.equ UART_BAUD_LO,  0x00
.equ UART_BAUD_HI,  0x01
.equ UART_CLOCK,    1843200
.equ BAUD_RATE,     115200
.equ BAUD_DIVISOR,  (UART_CLOCK / BAUD_RATE)

serial_init:
    li      t0, UART_BASE

    # disable interrupts (sounds like somthing you would do on x86 XD)
    sb      zero, UART_IER(t0)

    # set dlab to access baud divisor
    li      t1, UART_LCR_DLAB
    sb      t1, UART_LCR(t0)

    # set divisor lo/hi
    li      t1, (BAUD_DIVISOR & 0xFF)
    sb      t1, UART_BAUD_LO(t0)
    li      t1, ((BAUD_DIVISOR >> 8) & 0xFF)
    sb      t1, UART_BAUD_HI(t0)

    # 8 bits no parity 1 stop bit clear dlab
    li      t1, 0x03
    sb      t1, UART_LCR(t0)

    # enable and clear fifos 14 byte trigger
    li      t1, 0xC7
    sb      t1, UART_FCR(t0)

    # rts/dsr
    li      t1, 0x0B
    sb      t1, UART_MCR(t0)

    ret

serial_putc:
    li      t0, UART_BASE
.Lwait_thre:
    lb      t1, UART_LSR(t0)
    andi    t1, t1, UART_LSR_THRE
    beqz    t1, .Lwait_thre         # spin until TX ready
    sb      a0, UART_THR(t0)
    ret

serial_puts:
    mv      t2, a0                  # t2 = string pointer
.Lputs_loop:
    lb      t3, 0(t2)
    beqz    t3, .Lputs_done
    mv      a0, t3
    addi    sp, sp, -16
    sd      ra, 8(sp)
    sd      t2, 0(sp)
    call    serial_putc
    ld      t2, 0(sp)
    ld      ra, 8(sp)
    addi    sp, sp, 16
    addi    t2, t2, 1
    j       .Lputs_loop
.Lputs_done:
    ret

_serial_put_uint:
    addi    sp, sp, -48
    sd      ra, 40(sp)
    sd      s0, 32(sp)
    sd      s1, 24(sp)
    sd      s2, 16(sp)

    mv      s0, a0                  # value
    mv      s1, a1                  # base
    la      s2, fmt_buf
    addi    s2, s2, 31              # write from end of buffer
    sb      zero, 0(s2)             # null terminator

    beqz    s0, .Lput_zero

.Ldigit_loop:
    beqz    s0, .Ldigit_done
    remu    t0, s0, s1              # t0 = digit = val % base
    divu    s0, s0, s1              # val /= base
    li      t1, 10
    blt     t0, t1, .Ldigit_num
    # a-f for hex
    addi    t0, t0, 87              # 'a' - 10 = 87
    j       .Ldigit_store
.Ldigit_num:
    addi    t0, t0, 48              # '0'
.Ldigit_store:
    addi    s2, s2, -1
    sb      t0, 0(s2)
    j       .Ldigit_loop

.Lput_zero:
    addi    s2, s2, -1
    li      t0, 48                  # '0'
    sb      t0, 0(s2)

.Ldigit_done:
    mv      a0, s2
    ld      s2, 16(sp)
    ld      s1, 24(sp)
    ld      s0, 32(sp)
    ld      ra, 40(sp)
    addi    sp, sp, 48
    call    serial_puts
    ret

printk:
    addi    sp, sp, -80
    sd      ra, 72(sp)
    sd      s0, 64(sp)              # fmt pointer
    sd      s1, 56(sp)              # arg index
    sd      s2, 48(sp)
    sd      s3, 40(sp)
    sd      s4, 32(sp)
    sd      s5, 24(sp)
    sd      s6, 16(sp)
    sd      s7, 8(sp)

    # spill varargs a1-a7 onto stack so we can index them
    sd      a1, -8(sp)              # arg[0]  (sp-8)
    sd      a2, -16(sp)             # arg[1]
    sd      a3, -24(sp)             # arg[2]
    sd      a4, -32(sp)             # arg[3]
    sd      a5, -40(sp)             # arg[4]
    sd      a6, -48(sp)             # arg[5]
    sd      a7, -56(sp)             # arg[6]

    mv      s0, a0                  # s0 = fmt
    li      s1, 0                   # s1 = arg index

.Lprintk_loop:
    lb      t0, 0(s0)
    beqz    t0, .Lprintk_done

    li      t1, 37                  # '%'
    bne     t0, t1, .Lprintk_char

    # format specifier
    addi    s0, s0, 1
    lb      t0, 0(s0)               # specifier char

    li      t1, 37
    beq     t0, t1, .Lprintk_emit  # %%

    # load next vararg from spilled area
    li      t2, 7
    bge     s1, t2, .Lprintk_next   # out of args
    li      t3, -8
    mul     t3, s1, t3              # offset = index * -8
    add     t3, sp, t3              # &arg[index] relative to sp
    ld      s2, -8(t3)              # Hmm - simpler below:

    # actually compute addr = sp - 8 - (s1 * 8)
    slli    t3, s1, 3               # t3 = s1 * 8
    li      t4, 8
    add     t3, t3, t4
    sub     t3, sp, t3              # t3 = sp - 8 - s1*8
    ld      s2, 0(t3)               # s2 = arg value
    addi    s1, s1, 1               # advance arg index

    li      t1, 115                 # 's'
    beq     t0, t1, .Lprintk_str
    li      t1, 99                  # 'c'
    beq     t0, t1, .Lprintk_c
    li      t1, 100                 # 'd'
    beq     t0, t1, .Lprintk_d
    li      t1, 117                 # 'u'
    beq     t0, t1, .Lprintk_u
    li      t1, 120                 # 'x'
    beq     t0, t1, .Lprintk_x
    li      t1, 112                 # 'p'
    beq     t0, t1, .Lprintk_p
    j       .Lprintk_next

.Lprintk_str:
    mv      a0, s2
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    serial_puts
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    j       .Lprintk_next

.Lprintk_c:
    mv      a0, s2
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    serial_putc
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    j       .Lprintk_next

.Lprintk_d:
    # check sign, print '-' if negative
    bgez    s2, .Lprintk_d_pos
    li      a0, 45                  # '-'
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    sd      s2, 48(sp)
    call    serial_putc
    ld      s2, 48(sp)
    ld      s1, 56(sp)
    ld      s0, 64(sp)
    neg     s2, s2
.Lprintk_d_pos:
    mv      a0, s2
    li      a1, 10
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    _serial_put_uint
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    j       .Lprintk_next

.Lprintk_u:
    mv      a0, s2
    li      a1, 10
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    _serial_put_uint
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    j       .Lprintk_next

.Lprintk_x:
    mv      a0, s2
    li      a1, 16
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    _serial_put_uint
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    j       .Lprintk_next

.Lprintk_p:
    # print "0x" prefix then hex value
    li      a0, 48                  # '0'
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    sd      s2, 48(sp)
    call    serial_putc
    li      a0, 120                 # 'x'
    call    serial_putc
    ld      s2, 48(sp)
    ld      s1, 56(sp)
    ld      s0, 64(sp)
    mv      a0, s2
    li      a1, 16
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    _serial_put_uint
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    j       .Lprintk_next

.Lprintk_emit:
    # emit the literal char in t0
.Lprintk_char:
    mv      a0, t0
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    call    serial_putc
    ld      s0, 64(sp)
    ld      s1, 56(sp)

.Lprintk_next:
    addi    s0, s0, 1
    j       .Lprintk_loop

.Lprintk_done:
    ld      s7, 8(sp)
    ld      s6, 16(sp)
    ld      s5, 24(sp)
    ld      s4, 32(sp)
    ld      s3, 40(sp)
    ld      s2, 48(sp)
    ld      s1, 56(sp)
    ld      s0, 64(sp)
    ld      ra, 72(sp)
    addi    sp, sp, 80
    ret