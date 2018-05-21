extern __edata
extern __end

extern _kmain

global _main
global _kernel_pagemap

kernel_pagemap equ 0x800000

section .data

_kernel_pagemap: dd kernel_pagemap

section .text

bits 32
_main:
    lgdt [gdt_ptr]

    jmp 0x08:.pmode
  .pmode:
    bits 32
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0xeffff0

    ; clear bss
    mov edi, __edata
    mov ecx, __end
    sub ecx, __edata
    xor eax, eax
    rep stosb

    ; zero out page tables
    xor eax, eax
    mov edi, kernel_pagemap
    mov ecx, 1024 * (8 + 1)
    rep stosd

    ; set up page tables
    mov eax, 0x03
    mov edi, (kernel_pagemap + 4096)
    mov ecx, 1024 * 8
.loop0:
    stosd
    add eax, 0x1000
    loop .loop0

    ; set up page directories
    mov eax, (kernel_pagemap + 4096)
    or eax, 0x03
    mov edi, kernel_pagemap
    mov ecx, 8
.loop1:
    stosd
    add eax, 0x1000
    loop .loop1

    mov eax, kernel_pagemap
    mov cr3, eax

    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    mov eax, _kmain
    call eax

  .halt:
    cli
    hlt
    jmp .halt

align 4
multiboot_header:
    .magic dd 0x1BADB002
    .flags dd 0x00010000
    .checksum dd -(0x1BADB002 + 0x00010000)
    .header_addr dd multiboot_header
    .load_addr dd 0x100000
    .load_end_addr dd __edata
    .bss_end_addr dd __end
    .entry_addr dd _main

section .data

align 16
gdt_ptr:
    dw .gdt_end - .gdt_start - 1  ; GDT size
    dd .gdt_start                 ; GDT start

align 16
.gdt_start:

; Null descriptor (required)
.null_descriptor:
    dw 0x0000           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 00000000b        ; Access
    db 00000000b        ; Granularity
    db 0x00             ; Base (high 8 bits)

; 32 bit mode kernel
.kernel_code_32:
    dw 0xFFFF           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 10011010b        ; Access
    db 11001111b        ; Granularity
    db 0x00             ; Base (high 8 bits)

.kernel_data_32:
    dw 0xFFFF           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 10010010b        ; Access
    db 11001111b        ; Granularity
    db 0x00             ; Base (high 8 bits)

; 32 bit mode user
.user_code_32:
    dw 0xFFFF           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 11111010b        ; Access
    db 11001111b        ; Granularity
    db 0x00             ; Base (high 8 bits)

.user_data_32:
    dw 0xFFFF           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 11110010b        ; Access
    db 11001111b        ; Granularity
    db 0x00             ; Base (high 8 bits)

; Unreal mode
.unreal_code:
    dw 0xFFFF           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 10011010b        ; Access
    db 10001111b        ; Granularity
    db 0x00             ; Base (high 8 bits)

.unreal_data:
    dw 0xFFFF           ; Limit
    dw 0x0000           ; Base (low 16 bits)
    db 0x00             ; Base (mid 8 bits)
    db 10010010b        ; Access
    db 10001111b        ; Granularity
    db 0x00             ; Base (high 8 bits)

.gdt_end:
