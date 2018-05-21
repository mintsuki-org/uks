extern real_routine

global _get_e820

section .data

%define e820_size           e820_end - e820_bin
e820_bin:                   incbin "real/e820.bin"
e820_end:

section .text

bits 32

extern _e820_map

_get_e820:
    push ebx
    mov ebx, _e820_map
    push esi
    push edi
    push ebp

    mov esi, e820_bin
    mov ecx, e820_size
    call real_routine

    pop ebp
    pop edi
    pop esi
    pop ebx
    ret
