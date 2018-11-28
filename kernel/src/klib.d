import core.stdc.stdarg;
import vga_textmode;
import pmm;
import vmm;
import io;
import klib;

const int KPRN_INFO = 0;
const int KPRN_WARN = 1;
const int KPRN_ERR = 2;
const int KPRN_DBG = 3;

extern (C) void __assert(const(char)* exp, const(char)* file, uint line) {
    kprint(KPRN_ERR, "failed assertion: %s", exp);
    kprint(KPRN_ERR, "file: %s", file);
    kprint(KPRN_ERR, "line: %u", line);
    for (;;) {}
}

extern (C) void* memset(void *s, int c, size_t n) {
    ubyte* ptr = cast(ubyte*)s;
    for (size_t i = 0; i < n; i++)
        ptr[i] = cast(ubyte)c;
    return s;
}

extern (C) char* strcpy(char* dest, const char* src) {
    size_t i = 0;

    for (i = 0; src[i]; i++)
        dest[i] = src[i];

    dest[i] = 0;

    return dest;
}

extern (C) int strcmp(const char* dst, const char* src) {
    size_t i;

    for (i = 0; dst[i] == src[i]; i++) {
        if ((!dst[i]) && (!src[i])) return 0;
    }

    return 1;
}

extern (C) int strncmp(const char* dst, const char* src, size_t count) {
    size_t i;

    for (i = 0; i < count; i++)
        if (dst[i] != src[i]) return 1;

    return 0;
}

extern (C) size_t strlen(const char* str) {
    size_t len;
    for (len = 0; str[len]; len++) {}
    return len;
}

private void kputchar(char c) {
    outb(0xe9, c);
    text_putchar(c);
    return;
}

private void kputs(const char* str) {
    for (size_t i = 0; str[i]; i++) {
        kputchar(str[i]);
    }

    return;
}

private const char* base_conv_tab = "0123456789abcdef";

private void kprn_ui(ulong x) {
    int i;
    char[21] buf;

    buf[20] = 0;

    if (!x) {
        kputchar('0');
        return;
    }

    for (i = 19; x; i--) {
        buf[i] = base_conv_tab[x % 10];
        x /= 10;
    }

    i++;
    kputs(&buf[i]);

    return;
}

private void kprn_x(ulong x) {
    int i;
    char[17] buf;

    buf[16] = 0;

    if (!x) {
        kputs("0x0");
        return;
    }

    for (i = 15; x; i--) {
        buf[i] = base_conv_tab[x % 16];
        x /= 16;
    }

    i++;
    kputs("0x");
    kputs(&buf[i]);

    return;
}

extern (C) void kprint(int type, const char* format, ...) {
    va_list args;
    char* fmt = cast(char*)format;

    va_start(args, format);

    /* print timestamp */
    /*kputs("["); kprn_ui(uptime_sec); kputs(".");
    kprn_ui(uptime_raw); kputs("] ");*/

    switch (type) {
        case KPRN_INFO:
            kputs("\x1b[36minfo\x1b[37m: ");
            break;
        case KPRN_WARN:
            kputs("\x1b[33mwarning\x1b[37m: ");
            break;
        case KPRN_ERR:
            kputs("\x1b[31mERROR\x1b[37m: ");
            break;
        case KPRN_DBG:
            kputs("\x1b[36mDEBUG\x1b[37m: ");
            break;
        default:
            goto done;
    }

    for (;;) {
        while (*fmt && *fmt != '%')
            kputchar(*(fmt++));
        if (!*fmt++) {
            kputchar('\n');
            goto done;
        }
        switch (*fmt++) {
            case 's': {
                char* str;
                va_arg(args, str);
                if (!str)
                    kputs("(null)");
                else
                    kputs(str);
                break;
            }
            case 'u': {
                uint x;
                va_arg(args, x);
                kprn_ui(cast(ulong)x);
                break;
            }
            case 'U': {
                ulong x;
                va_arg(args, x);
                kprn_ui(x);
                break;
            }
            case 'x': {
                uint x;
                va_arg(args, x);
                kprn_x(cast(ulong)x);
                break;
            }
            case 'X': {
                ulong x;
                va_arg(args, x);
                kprn_x(x);
                break;
            }
            case 'c': {
                char c;
                va_arg(args, c);
                kputchar(c);
                break;
            }
            default:
                kputchar('?');
                break;
        }
    }

done:
    return;
}

private struct alloc_metadata_t {
    size_t pages;
    size_t size;
}

void* kalloc(size_t size) {
    size_t page_count = size / PAGE_SIZE;
    if (size % PAGE_SIZE) page_count++;

    ubyte* ptr = cast(ubyte*)pmm_alloc(page_count + 1);

    if (!ptr) {
        return cast(void*)0;
    }

    alloc_metadata_t* metadata = cast(alloc_metadata_t*)ptr;
    ptr += PAGE_SIZE;

    metadata.pages = page_count;
    metadata.size = size;

    // Zero pages.
    for (size_t i = 0; i < (page_count * PAGE_SIZE); i++)
        ptr[i] = 0;

    return cast(void *)ptr;
}

void kfree(void* ptr) {
    alloc_metadata_t* metadata = cast(alloc_metadata_t*)(cast(size_t)ptr - PAGE_SIZE);

    pmm_free(cast(void*)metadata, metadata.pages + 1);
}
