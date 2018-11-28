import io;
import vmm;

private const uint VD_COLS = (80 * 2);
private const uint VD_ROWS = 25;
private const uint VIDEO_BOTTOM = ((VD_ROWS * VD_COLS) - 1);

private __gshared char* video_mem = cast(char*)(cast(size_t)0xb8000 + MEM_PHYS_OFFSET);
private __gshared uint cursor_offset = 0;
private __gshared bool cursor_status = true;
private __gshared ubyte text_palette = 0x07;
private __gshared ubyte cursor_palette = 0x70;
private __gshared bool escape = false;
private __gshared int esc_value0 = 0;
private __gshared int esc_value1 = 0;
private __gshared int* esc_value = &esc_value0;
private __gshared int esc_default0 = 1;
private __gshared int esc_default1 = 1;
private __gshared int* esc_default = &esc_default0;

void init_vga_textmode() {
    outb(0x3d4, 0x0a);
    outb(0x3d5, 0x20);
    text_clear();
    return;
}

void text_putstring(const char* str) {
    for (size_t i = 0; str[i]; i++)
        text_putchar(str[i]);
    return;
}

private void clear_cursor() {
    video_mem[cursor_offset + 1] = text_palette;
    return;
}

private void draw_cursor() {
    if (cursor_status) {
        video_mem[cursor_offset + 1] = cursor_palette;
    }
    return;
}

private void scroll() {
    // move the text up by one row
    for (size_t i = 0; i <= VIDEO_BOTTOM - VD_COLS; i++)
        video_mem[i] = video_mem[i + VD_COLS];
    // clear the last line of the screen
    for (size_t i = VIDEO_BOTTOM; i > VIDEO_BOTTOM - VD_COLS; i -= 2) {
        video_mem[i] = text_palette;
        video_mem[i - 1] = ' ';
    }
    return;
}

void text_clear() {
    clear_cursor();
    for (size_t i = 0; i < VIDEO_BOTTOM; i += 2) {
        video_mem[i] = ' ';
        video_mem[i + 1] = text_palette;
    }
    cursor_offset = 0;
    draw_cursor();
    return;
}

private void text_clear_no_move() {
    clear_cursor();
    for (size_t i = 0; i < VIDEO_BOTTOM; i += 2) {
        video_mem[i] = ' ';
        video_mem[i + 1] = text_palette;
    }
    draw_cursor();
    return;
}

void text_enable_cursor() {
    cursor_status = true;
    draw_cursor();
    return;
}

void text_disable_cursor() {
    cursor_status = false;
    clear_cursor();
    return;
}

void text_putchar(char c) {
    if (escape) {
        escape_parse(c);
        return;
    }
    switch (c) {
        case 0x00:
            break;
        case 0x1B:
            escape = true;
            return;
        case 0x0A:
            if (text_get_cursor_pos_y() == (VD_ROWS - 1)) {
                clear_cursor();
                scroll();
                text_set_cursor_pos(0, (VD_ROWS - 1));
            } else {
                text_set_cursor_pos(0, (text_get_cursor_pos_y() + 1));
            }
            break;
        case 0x08:
            if (cursor_offset) {
                clear_cursor();
                cursor_offset -= 2;
                video_mem[cursor_offset] = ' ';
                draw_cursor();
            }
            break;
        default:
            clear_cursor();
            video_mem[cursor_offset] = cast(ubyte)c;
            if (cursor_offset >= (VIDEO_BOTTOM - 1)) {
                scroll();
                cursor_offset = VIDEO_BOTTOM - (VD_COLS - 1);
            } else
                cursor_offset += 2;
            draw_cursor();
    }
    return;
}

private const ubyte[] ansi_colours = [0, 4, 2, 6, 1, 5, 3, 7];

private void sgr() {

    if (esc_value0 >= 30 && esc_value0 <= 37) {
        ubyte pal = text_get_text_palette();
        pal = (pal & cast(ubyte)0xf0) | ansi_colours[esc_value0 - 30];
        text_set_text_palette(pal);
        return;
    }

    if (esc_value0 >= 40 && esc_value0 <= 47) {
        ubyte pal = text_get_text_palette();
        pal = (pal & cast(ubyte)0x0f) | cast(ubyte)(ansi_colours[esc_value0 - 40] << 4);
        text_set_text_palette(pal);
        return;
    }

    return;
}

private void escape_parse(char c) {

    if (c >= '0' && c <= '9') {
        *esc_value *= 10;
        *esc_value += c - '0';
        *esc_default = 0;
        return;
    }

    switch (c) {
        case '[':
            return;
        case ';':
            esc_value = &esc_value1;
            esc_default = &esc_default1;
            return;
        case 'A':
            if (esc_default0)
                esc_value0 = 1;
            if (esc_value0 > text_get_cursor_pos_y())
                esc_value0 = text_get_cursor_pos_y();
            text_set_cursor_pos(text_get_cursor_pos_x(),
                                text_get_cursor_pos_y() - esc_value0);
            break;
        case 'B':
            if (esc_default0)
                esc_value0 = 1;
            if ((text_get_cursor_pos_y() + esc_value0) > (VD_ROWS - 1))
                esc_value0 = (VD_ROWS - 1) - text_get_cursor_pos_y();
            text_set_cursor_pos(text_get_cursor_pos_x(),
                                text_get_cursor_pos_y() + esc_value0);
            break;
        case 'C':
            if (esc_default0)
                esc_value0 = 1;
            if ((text_get_cursor_pos_x() + esc_value0) > (VD_COLS / 2 - 1))
                esc_value0 = (VD_COLS / 2 - 1) - text_get_cursor_pos_x();
            text_set_cursor_pos(text_get_cursor_pos_x() + esc_value0,
                                text_get_cursor_pos_y());
            break;
        case 'D':
            if (esc_default0)
                esc_value0 = 1;
            if (esc_value0 > text_get_cursor_pos_x())
                esc_value0 = text_get_cursor_pos_x();
            text_set_cursor_pos(text_get_cursor_pos_x() - esc_value0,
                                text_get_cursor_pos_y());
            break;
        case 'H':
            esc_value0--;
            esc_value1--;
            if (esc_default0)
                esc_value0 = 0;
            if (esc_default1)
                esc_value1 = 0;
            if (esc_value1 >= (VD_COLS / 2))
                esc_value1 = (VD_COLS / 2) - 1;
            if (esc_value0 >= VD_ROWS)
                esc_value0 = VD_ROWS - 1;
            text_set_cursor_pos(esc_value1, esc_value0);
            break;
        case 'm':
            sgr();
            break;
        case 'J':
            switch (esc_value0) {
                case 2:
                    text_clear_no_move();
                    break;
                default:
                    break;
            }
            break;
        default:
            text_putchar('?');
            break;
    }

    esc_value = &esc_value0;
    esc_value0 = 0;
    esc_value1 = 0;
    esc_default = &esc_default0;
    esc_default0 = 1;
    esc_default1 = 1;
    escape = false;

    return;
}

void text_set_cursor_palette(ubyte c) {
    cursor_palette = c;
    draw_cursor();
    return;
}

ubyte text_get_cursor_palette() {
    return cursor_palette;
}

void text_set_text_palette(ubyte c) {
    text_palette = c;
    return;
}

ubyte text_get_text_palette() {
    return text_palette;
}

int text_get_cursor_pos_x() {
    return (cursor_offset % VD_COLS) / 2;
}

int text_get_cursor_pos_y() {
    return cursor_offset / VD_COLS;
}

void text_set_cursor_pos(int x, int y) {
    clear_cursor();
    cursor_offset = y * VD_COLS + x * 2;
    draw_cursor();
    return;
}
