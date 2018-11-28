OUTPUT_FORMAT(binary)
ENTRY(_start)

SECTIONS
{
    kernel_phys_offset = 0xffffffffc0000000;
    . = kernel_phys_offset + 0x100000;

    .text :
    {
        sections_text = . - kernel_phys_offset;
        KEEP(*(.multiboot))
        KEEP(*(.text*))
        sections_text_end = . - kernel_phys_offset;
    }

    .data :
    {
        sections_data = . - kernel_phys_offset;
        KEEP(*(.data*))
        KEEP(*(.rodata*))
        KEEP(*(.eh_frame*))
        sections_data_end = . - kernel_phys_offset;
    }

    .bss :
    {
        sections_bss = . - kernel_phys_offset;
        KEEP(*(COMMON))
        KEEP(*(.bss*))
        sections_bss_end = . - kernel_phys_offset;
    }
}
