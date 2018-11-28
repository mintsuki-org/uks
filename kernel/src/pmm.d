import e820;
import klib;
import vmm;

private const size_t MEMORY_BASE = 0x1000000;
private const size_t BITMAP_BASE = (MEMORY_BASE / PAGE_SIZE);

private const size_t BMREALLOC_STEP = 1;

private __gshared uint* mem_bitmap;
private __gshared uint[] initial_bitmap = [0xfffffffe];
private __gshared uint* tmp_bitmap;

// 32 entries because initial_bitmap is a single dword.
private __gshared size_t bitmap_entries = 32;

private bool read_bitmap(size_t i) {
    i -= BITMAP_BASE;

    size_t which_entry = i / 32;
    size_t offset = i % 32;

    return cast(bool)((mem_bitmap[which_entry] >> offset) & 1);
}

private void write_bitmap(size_t i, bool val) {
    i -= BITMAP_BASE;

    size_t which_entry = i / 32;
    size_t offset = i % 32;

    if (val)
        mem_bitmap[which_entry] |= (1 << offset);
    else
        mem_bitmap[which_entry] &= ~(1 << offset);

    return;
}

// Populate bitmap using e820 data.
void init_pmm() {
    kprint(KPRN_INFO, "pmm: Initialising physical memory manager...");

    mem_bitmap = &initial_bitmap[0];
    tmp_bitmap = cast(uint*)pmm_alloc(BMREALLOC_STEP);
    if (!tmp_bitmap) {
        kprint(KPRN_ERR, "pmm_alloc failure in init_pmm(). Halted.");
        for (;;) {}
    }

    tmp_bitmap = cast(uint*)(cast(size_t)tmp_bitmap + MEM_PHYS_OFFSET);

    for (size_t i = 0; i < (BMREALLOC_STEP * PAGE_SIZE) / uint.sizeof; i++)
        tmp_bitmap[i] = 0xffffffff;

    mem_bitmap = tmp_bitmap;

    bitmap_entries = ((PAGE_SIZE / uint.sizeof) * 32) * BMREALLOC_STEP;

    // For each region specified by the e820, iterate over each page which
    // fits in that region and if the region type indicates the area itself
    // is usable, write that page as free in the bitmap. Otherwise, mark the page as used.
    for (size_t i = 0; e820_map[i].type; i++) {
        if (e820_map[i].type != 1)
            continue;

        size_t aligned_base;
        if (e820_map[i].base % PAGE_SIZE)
            aligned_base = e820_map[i].base + (PAGE_SIZE - (e820_map[i].base % PAGE_SIZE));
        else
            aligned_base = e820_map[i].base;
        size_t aligned_length = (e820_map[i].length / PAGE_SIZE) * PAGE_SIZE;
        if ((e820_map[i].base % PAGE_SIZE) && aligned_length) aligned_length -= PAGE_SIZE;

        for (size_t j = 0; j * PAGE_SIZE < aligned_length; j++) {
            size_t addr = aligned_base + j * PAGE_SIZE;

            size_t page = addr / PAGE_SIZE;

            if (addr < (MEMORY_BASE + PAGE_SIZE))
                continue;

            while (addr >= (MEMORY_BASE + bitmap_entries * PAGE_SIZE)) {
                // Reallocate bitmap
                size_t cur_bitmap_size_in_pages = ((bitmap_entries / 32) * uint.sizeof) / PAGE_SIZE;
                size_t new_bitmap_size_in_pages = cur_bitmap_size_in_pages + BMREALLOC_STEP;
                tmp_bitmap = cast(uint*)pmm_alloc(new_bitmap_size_in_pages);
                if (!tmp_bitmap) {
                    kprint(KPRN_ERR, "pmm_alloc failure in init_pmm(). Halted.");
                    for (;;) {}
                }
                tmp_bitmap = cast(uint*)(cast(size_t)tmp_bitmap + MEM_PHYS_OFFSET);
                // Copy over previous bitmap
                for (size_t ii = 0;
                     ii < (cur_bitmap_size_in_pages * PAGE_SIZE) / uint.sizeof;
                     ii++)
                    tmp_bitmap[ii] = mem_bitmap[ii];
                // Fill in the rest
                for (size_t ii = (cur_bitmap_size_in_pages * PAGE_SIZE) / uint.sizeof;
                     ii < (new_bitmap_size_in_pages * PAGE_SIZE) / uint.sizeof;
                     ii++)
                    tmp_bitmap[ii] = 0xffffffff;
                bitmap_entries += ((PAGE_SIZE / uint.sizeof) * 32) * BMREALLOC_STEP;
                uint* old_bitmap = cast(uint*)(cast(size_t)mem_bitmap - MEM_PHYS_OFFSET);
                mem_bitmap = tmp_bitmap;
                pmm_free(old_bitmap, cur_bitmap_size_in_pages);
            }

            write_bitmap(page, 0);
        }
    }

    kprint(KPRN_INFO, "pmm: Done.");
    return;
}

// Allocate physical memory.
void* pmm_alloc(size_t pg_count) {
    // Allocate contiguous free pages.
    size_t counter = 0;
    size_t i;
    size_t start;

    for (i = BITMAP_BASE; i < BITMAP_BASE + bitmap_entries; i++) {
        if (!read_bitmap(i))
            counter++;
        else
            counter = 0;
        if (counter == pg_count)
            goto found;
    }
    return cast(void*)0;

found:
    start = i - (pg_count - 1);
    for (i = start; i < (start + pg_count); i++) {
        write_bitmap(i, 1);
    }

    // Zero out these pages addressing through the higher half
    uint* pages = cast(uint*)((start * PAGE_SIZE) + MEM_PHYS_OFFSET);
    for (size_t j = 0; j < (pg_count * PAGE_SIZE) / uint.sizeof; j++)
        pages[j] = 0;

    // Return the physical address that represents the start of this physical page(s).
    return cast(void*)(start * PAGE_SIZE);
}

// Release physical memory.
void pmm_free(void* ptr, size_t pg_count) {
    size_t start = cast(size_t)ptr / PAGE_SIZE;

    for (size_t i = start; i < (start + pg_count); i++) {
        write_bitmap(i, 0);
    }

    return;
}
