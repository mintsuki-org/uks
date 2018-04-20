#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <klib.h>
#include <vga_textmode.h>

char *kstrcpy(char *dest, char *src) {
    size_t i = 0;

    for (i = 0; src[i]; i++)
        dest[i] = src[i];

    dest[i] = 0;

    return dest;
}

int kstrcmp(char *dst, char *src) {
    size_t i;

    for (i = 0; dst[i] == src[i]; i++) {
        if ((!dst[i]) && (!src[i])) return 0;
    }

    return 1;
}

int kstrncmp(char *dst, char *src, size_t count) {
    size_t i;

    for (i = 0; i < count; i++)
        if (dst[i] != src[i]) return 1;

    return 0;
}

size_t kstrlen(char *str) {
    size_t len;

    for (len = 0; str[len]; len++);

    return len;
}

static void kputchar(char c) {
    text_putchar(c);
    return;
}

static void kputs(char *string) {
    size_t i;
    
    for (i = 0; string[i]; i++) {
        kputchar(string[i]);
    }

    return;
}

static char base_conv_tab[] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
};

static void kprn_ui(uint32_t x) {
    int i;
    char buf[11];

    buf[10] = 0;

    if (!x) {
        kputchar('0');
        return;
    }

    for (i = 9; x; i--) {
        buf[i] = base_conv_tab[(x % 10)];
        x /= 10;
    }

    i++;
    kputs(buf + i);

    return;
}

static void kprn_x(uint32_t x) {
    int i;
    char buf[9];

    buf[8] = 0;

    if (!x) {
        kputs("0x0");
        return;
    }

    for (i = 7; x; i--) {
        buf[i] = base_conv_tab[(x % 16)];
        x /= 16;
    }

    i++;
    kputs("0x");
    kputs(buf + i);

    return;
}

void kprint(int type, char *fmt, ...) {
    char *str;
    va_list args;

    va_start(args, fmt);

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
            goto out;
    }

    for (;;) {
        char c;

        while (*fmt && *fmt != '%')
            kputchar(*(fmt++));
        if (!*fmt++) {
            va_end(args);
            kputchar('\n');
            goto out;
        }
        switch (*fmt++) {
            case 's':
                str = va_arg(args, char *);
                if (!str)
                    kputs("(null)");
                else
                    kputs(str);
                break;
            case 'u':
                kprn_ui(va_arg(args, uint32_t));
                break;
            case 'x':
                kprn_x(va_arg(args, uint32_t));
                break;
            case 'c':
                c = (char)va_arg(args, int);
                kputchar(c);
                break;
            default:
                kputchar('?');
                break;
        }
    }

out:
    return;
}

void *kmemcpy(void *dest, void *src, size_t count) {
    size_t i = 0;

    uint8_t *dest2 = dest;
    uint8_t *src2 = src;
    
    /* Copy byte by byte */
    for (i = 0; i < count; i++) {
        dest2[i] = src2[i];
    }
    
    return dest;
}

void *kmemset(void *s, int c, size_t count) {
    uint8_t *p = s, *end = p + count;
    for (; p != end; p++) {
        *p = (uint8_t)c;
    }

    return s;    
}

void *kmemmove(void *dest, void *src, size_t count) {
    size_t i = 0;

    uint8_t *dest2 = dest;
    uint8_t *src2 = src;

    if (src > dest) {
        for (i = 0; i < count; i++) {
            dest2[i] = src2[i];
        }
    } else {
        for (i = count; i > 0; i--) {
            dest2[i - 1] = src2[i];
        }
    }

    return dest;
}

int kmemcmp(void *s1, void *s2, size_t n) {
    uint8_t *a = s1;
    uint8_t *b = s2;
    size_t i;
    
    for (i = 0; i < n; i++) {
        if (a[i] < b[i]) {
            return -1;
        } else if (a[i] > b[i]) {
            return 1;
        }
    }

    return 0;
}
