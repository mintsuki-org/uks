#include <stdint.h>
#include <cio.h>

void port_out_b(uint16_t port, uint8_t value) {
#asm
    mov edx, [esp+4]
    mov eax, [esp+8]
    out dx, al
#endasm
}
