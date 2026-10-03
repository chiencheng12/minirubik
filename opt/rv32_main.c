/* Bare-metal front end for running the C build of fast.c on Ripes.
 * The state is compiled in (-DSTATE='"..."'); output goes through Ripes
 * environment calls (a7 = 4 print string, a7 = 1 print int, a7 = 10 exit).
 */
#include <stdint.h>

#include "fast.h"

#ifndef STATE
#define STATE "21345671111111"
#endif

static const char *const move_names[9] = {"R ",  "R2 ", "R' ", "B ", "B2 ",
                                          "B' ", "D ",  "D2 ", "D' "};

static void ecall1(uint32_t service, uint32_t arg)
{
    register uint32_t a0 __asm__("a0") = arg;
    register uint32_t a7 __asm__("a7") = service;
    __asm__ volatile("ecall" : "+r"(a0) : "r"(a7) : "memory");
}

int main(void)
{
    uint8_t path[11];
    int len = fast_solve(STATE, path);
    for (int i = 0; i < len; i++)
        ecall1(4, (uint32_t) move_names[path[i]]);
    ecall1(4, (uint32_t) "\n");
    return len;
}

void _start(void) __attribute__((naked, section(".text.start")));
void _start(void)
{
    __asm__ volatile("li sp, 0x7ffffff0\n"
                     "call main\n"
                     "li a7, 10\n"
                     "ecall\n");
}
