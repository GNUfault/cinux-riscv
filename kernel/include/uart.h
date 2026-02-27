#ifndef PRINTK_H
#define PRINTK_H

#include "stdint.h"
#include "stdarg.h"

#define UART_BASE       0x10000000UL
#define UART_THR        0x00
#define UART_RBR        0x00
#define UART_IER        0x01
#define UART_FCR        0x02
#define UART_LCR        0x03
#define UART_MCR        0x04
#define UART_LSR        0x05
#define UART_LSR_THRE   0x20
#define UART_LCR_DLAB   0x80

#define UART_CLOCK      1843200UL
#define BAUD_RATE       115200UL
#define BAUD_DIVISOR    (UART_CLOCK / BAUD_RATE)

void serial_init(void);
void serial_putc(int c);
void serial_puts(const char *s);
void printk(const char *fmt, ...);

#endif /* PRINTK_H */