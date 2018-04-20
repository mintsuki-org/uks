#include <stdint.h>
#include <vga_textmode.h>
#include <klib.h>
#include <e820.h>
#include <mm.h>

void kmain(void) {
    init_vga_textmode();

    kprint(KPRN_INFO, "uks: Kernel booted");

    init_e820();
    init_pmm();
    init_vmm();

    for (;;) {
        #asm
            hlt
        #endasm
    }
}
