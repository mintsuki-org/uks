#include <stdint.h>
#include <vga_textmode.h>
#include <klib.h>

void kmain(void) {
    init_vga_textmode();

    kprint(KPRN_INFO, "uks: Kernel booted");

    for (;;) {
        #asm
            hlt
        #endasm
    }
}
