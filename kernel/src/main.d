import vga_textmode;
import klib;
import e820;
import pmm;
import vmm;

extern (C) void kmain() {
    init_vga_textmode();

    kprint(KPRN_INFO, "uks: Kernel booted");

    init_e820();
    init_pmm();
    init_vmm();

    kprint(KPRN_INFO, "uks: End of kmain");

    for (;;) {}
}
