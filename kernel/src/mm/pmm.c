#include <stdint.h>
#include <stddef.h>
#include <mm.h>
#include <klib.h>
#include <e820.h>

#define MBITMAP_FULL ((0x4000000 / PAGE_SIZE) / 32)
static size_t bitmap_full = MBITMAP_FULL;
#define BASE (0x1000000 / PAGE_SIZE)

static uint32_t *mem_bitmap;
static uint32_t initial_bitmap[MBITMAP_FULL];
static uint32_t *tmp_bitmap;

static int read_bitmap(size_t i) {
    size_t which_entry = i / 32;
    size_t offset = i % 32;

    return (int)((mem_bitmap[which_entry] >> offset) & 1);
}

static void write_bitmap(size_t i, int val) {
    size_t which_entry = i / 32;
    size_t offset = i % 32;

    if (val)
        mem_bitmap[which_entry] |= (1 << offset);
    else
        mem_bitmap[which_entry] &= ~(1 << offset);

    return;
}

static void bm_realloc(void) {
    size_t i;
    uint32_t *tmp;

    if (!(tmp_bitmap = kalloc((bitmap_full + 2048) * sizeof(uint32_t)))) {
        kprint(KPRN_ERR, "kalloc failure in bm_realloc(). Halted.");
        for (;;);
    }

    kmemcpy((void *)tmp_bitmap, (void *)mem_bitmap, bitmap_full * sizeof(uint32_t));
    for (i = bitmap_full; i < bitmap_full + 2048; i++) {
        tmp_bitmap[i] = 0xffffffff;
    }

    bitmap_full += 2048;

    tmp = tmp_bitmap;
    tmp_bitmap = mem_bitmap;
    mem_bitmap = tmp;

    kfree((void *)tmp_bitmap);

    return;
}

/* Populate bitmap using e820 data. */
void init_pmm(void) {
    size_t i;

    kprint(KPRN_INFO, "pmm: Initialising...");

    for (i = 0; i < bitmap_full; i++) {
        initial_bitmap[i] = 0;
    }

    mem_bitmap = initial_bitmap;
    if (!(tmp_bitmap = kalloc(bitmap_full * sizeof(uint32_t)))) {
        kprint(KPRN_ERR, "kalloc failure in init_pmm(). Halted.");
        for (;;);
    }

    for (i = 0; i < bitmap_full; i++)
        tmp_bitmap[i] = initial_bitmap[i];
    mem_bitmap = tmp_bitmap;

    /* For each region specified by the e820, iterate over each page which
       fits in that region and if the region type indicates the area itself
       is usable, write that page as free in the bitmap. Otherwise, mark the page as used. */
    for (i = 0; e820_map[i].type; i++) {
        size_t j;

        if (e820_map[i].base_high || e820_map[i].length_high)
            continue;

        if (e820_map[i].base + e820_map[i].length < e820_map[i].base) {
            /* overflow check */
            continue;
        }

        for (j = 0; j * PAGE_SIZE < e820_map[i].length; j++) {
            size_t addr = e820_map[i].base + j * PAGE_SIZE;
            size_t page = addr / PAGE_SIZE;

            /* FIXME: assume the first 32 MiB of memory to be free and usable */
            if (addr < 0x2000000)
                continue;

            while (page >= bitmap_full * 32)
                bm_realloc();
            if (e820_map[i].type == 1)
                write_bitmap(page, 0);
            else
                write_bitmap(page, 1);
        }
    }

    kprint(KPRN_INFO, "pmm: Done");

    return;
}

/* Allocate physical memory. */
void *pmm_alloc(size_t pg_count) {
    /* Allocate contiguous free pages. */
    size_t counter = 0;
    size_t i;
    size_t start;

    for (i = BASE; i < bitmap_full * 32; i++) {
        if (!read_bitmap(i))
            counter++;
        else
            counter = 0;
        if (counter == pg_count)
            goto found;
    }
    return (void *)0;

found:
    start = i - (pg_count - 1);
    for (i = start; i < (start + pg_count); i++) {
        write_bitmap(i, 1);
    }
    
    /* Return the physical address that represents the start of this physical page(s). */
    return (void *)(start * PAGE_SIZE);
}

/* Release physical memory. */
void pmm_free(void *ptr, size_t pg_count) {
    size_t start = (size_t)ptr / PAGE_SIZE;
    size_t i;

    for (i = start; i < (start + pg_count); i++) {
        write_bitmap(i, 0);
    }

    return;
}
