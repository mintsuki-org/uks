import klib;
import pmm;
import e820;

const size_t PAGE_SIZE = 4096;
const size_t MEM_PHYS_OFFSET = 0xffff8000_00000000;
const size_t KERNEL_PHYS_OFFSET = 0xffffffff_c0000000;
const size_t PAGE_TABLE_ENTRIES = 512;
alias pt_entry_t = size_t;
__gshared pt_entry_t* kernel_pagemap;

// map physaddr -> virtaddr using pml4 pointer
// Returns 0 on success, -1 on failure
int map_page(pt_entry_t* pagemap, size_t virt_addr, size_t phys_addr, size_t flags) {
    // Calculate the indices in the various tables using the virtual address
    size_t pml4_entry = (virt_addr & (cast(size_t)0x1ff << 39)) >> 39;
    size_t pdpt_entry = (virt_addr & (cast(size_t)0x1ff << 30)) >> 30;
    size_t pd_entry = (virt_addr & (cast(size_t)0x1ff << 21)) >> 21;
    size_t pt_entry = (virt_addr & (cast(size_t)0x1ff << 12)) >> 12;

    pt_entry_t* pdpt, pd, pt;

    if (pagemap[pml4_entry] & 0x1) {
        pdpt = cast(pt_entry_t*)((pagemap[pml4_entry] & 0xfffffffffffff000) + MEM_PHYS_OFFSET);
    } else {
        // Allocate a page for the pdpt.
        pdpt = cast(pt_entry_t*)(cast(size_t)pmm_alloc(1) + MEM_PHYS_OFFSET);
        // Catch allocation failure
        if (cast(size_t)pdpt == MEM_PHYS_OFFSET)
            goto fail1;
        // Present + writable + user (0b111)
        pagemap[pml4_entry] = cast(pt_entry_t)(cast(size_t)pdpt - MEM_PHYS_OFFSET) | 0b111;
    }

    if (pdpt[pdpt_entry] & 0x1) {
        pd = cast(pt_entry_t*)((pdpt[pdpt_entry] & 0xfffffffffffff000) + MEM_PHYS_OFFSET);
    } else {
        // Allocate a page for the pd.
        pd = cast(pt_entry_t*)(cast(size_t)pmm_alloc(1) + MEM_PHYS_OFFSET);
        // Catch allocation failure
        if (cast(size_t)pdpt == MEM_PHYS_OFFSET)
            goto fail2;
        // Present + writable + user (0b111)
        pdpt[pdpt_entry] = cast(pt_entry_t)(cast(size_t)pd - MEM_PHYS_OFFSET) | 0b111;
    }

    if (pd[pd_entry] & 0x1) {
        pt = cast(pt_entry_t*)((pd[pd_entry] & 0xfffffffffffff000) + MEM_PHYS_OFFSET);
    } else {
        // Allocate a page for the pt.
        pt = cast(pt_entry_t*)(cast(size_t)pmm_alloc(1) + MEM_PHYS_OFFSET);
        // Catch allocation failure
        if (cast(size_t)pdpt == MEM_PHYS_OFFSET)
            goto fail3;
        // Present + writable + user (0b111)
        pd[pd_entry] = cast(pt_entry_t)(cast(size_t)pt - MEM_PHYS_OFFSET) | 0b111;
    }

    // Set the entry as present and point it to the passed physical address
    // Also set the specified flags
    pt[pt_entry] = cast(pt_entry_t)(phys_addr | flags);

    return 0;

    // Free previous levels if empty
fail3:
    for (size_t i = 0; ; i++) {
        if (i == PAGE_TABLE_ENTRIES) {
            // We reached the end, table is free
            pmm_free(cast(void*)pd - MEM_PHYS_OFFSET, 1);
            break;
        }
        if (pd[i] & 0x1) {
            // Table is not free
            goto fail1;
        }
    }

fail2:
    for (size_t i = 0; ; i++) {
        if (i == PAGE_TABLE_ENTRIES) {
            // We reached the end, table is free
            pmm_free(cast(void*)pdpt - MEM_PHYS_OFFSET, 1);
            break;
        }
        if (pdpt[i] & 0x1) {
            // Table is not free
            goto fail1;
        }
    }

fail1:
    return -1;
}

int unmap_page(pt_entry_t* pagemap, size_t virt_addr) {
    // Calculate the indices in the various tables using the virtual address
    size_t pml4_entry = (virt_addr & (cast(size_t)0x1ff << 39)) >> 39;
    size_t pdpt_entry = (virt_addr & (cast(size_t)0x1ff << 30)) >> 30;
    size_t pd_entry = (virt_addr & (cast(size_t)0x1ff << 21)) >> 21;
    size_t pt_entry = (virt_addr & (cast(size_t)0x1ff << 12)) >> 12;

    pt_entry_t* pdpt, pd, pt;

    // Get reference to the various tables in sequence. Return -1 if one of the tables is not present,
    // since we cannot unmap a virtual address if we don't know what it's mapped to in the first place
    if (pagemap[pml4_entry] & 0x1) {
        pdpt = cast(pt_entry_t*)((pagemap[pml4_entry] & 0xfffffffffffff000) + MEM_PHYS_OFFSET);
    } else {
        goto fail;
    }

    if (pdpt[pdpt_entry] & 0x1) {
        pd = cast(pt_entry_t*)((pdpt[pdpt_entry] & 0xfffffffffffff000) + MEM_PHYS_OFFSET);
    } else {
        goto fail;
    }

    if (pd[pd_entry] & 0x1) {
        pt = cast(pt_entry_t*)((pd[pd_entry] & 0xfffffffffffff000) + MEM_PHYS_OFFSET);
    } else {
        goto fail;
    }

    // Unmap entry
    pt[pt_entry] = 0;

    // Free previous levels if empty
    for (size_t i = 0; ; i++) {
        if (i == PAGE_TABLE_ENTRIES) {
            // We reached the end, table is free
            pmm_free(cast(void*)pt - MEM_PHYS_OFFSET, 1);
            break;
        }
        if (pt[i] & 0x1) {
            // Table is not free
            goto done;
        }
    }

    for (size_t i = 0; ; i++) {
        if (i == PAGE_TABLE_ENTRIES) {
            // We reached the end, table is free
            pmm_free(cast(void*)pd - MEM_PHYS_OFFSET, 1);
            break;
        }
        if (pd[i] & 0x1) {
            // Table is not free
            goto done;
        }
    }

    for (size_t i = 0; ; i++) {
        if (i == PAGE_TABLE_ENTRIES) {
            // We reached the end, table is free
            pmm_free(cast(void*)pdpt - MEM_PHYS_OFFSET, 1);
            break;
        }
        if (pdpt[i] & 0x1) {
            // Table is not free
            goto done;
        }
    }

done:
    return 0;

fail:
    return -1;
}

// Map the first 4GiB of memory, this saves issues with MMIO hardware < 4GiB later on
// Then use the e820 to map all the available memory (saves on allocation time and it's easier)
// The physical memory is mapped at the beginning of the higher half (entry 256 of the pml4) onwards
void init_vmm() {
    kprint(KPRN_INFO, "vmm: Initialising virtual memory manager...");

    kernel_pagemap = cast(pt_entry_t*)(cast(size_t)pmm_alloc(1) + MEM_PHYS_OFFSET);
    // Catch allocation failure
    if (cast(size_t)kernel_pagemap == MEM_PHYS_OFFSET) {
        kprint(KPRN_ERR, "pmm_alloc failure in init_vmm(). Halted.");
        for (;;) {}
    }

    // Identity map the first 32 MiB
    // Map 32 MiB for the phys mem area, and 32 MiB for the kernel in the higher half
    for (size_t i = 0; i < (0x2000000 / PAGE_SIZE); i++) {
        size_t addr = i * PAGE_SIZE;
        map_page(kernel_pagemap, addr, addr, 0x03);
        map_page(kernel_pagemap, MEM_PHYS_OFFSET + addr, addr, 0x03);
        map_page(kernel_pagemap, KERNEL_PHYS_OFFSET + addr, addr, 0x03);
    }

    // Reload new pagemap
    size_t new_cr3 = cast(size_t)kernel_pagemap - MEM_PHYS_OFFSET;
    asm {
        mov RAX, new_cr3;
        mov CR3, RAX;
    }

    // Forcefully map the first 4 GiB for I/O into the higher half
    for (size_t i = 0; i < (0x100000000 / PAGE_SIZE); i++) {
        size_t addr = i * PAGE_SIZE;
        map_page(kernel_pagemap, MEM_PHYS_OFFSET + addr, addr, 0x03);
    }

    // Map the rest according to e820 into the higher half
    for (size_t i = 0; e820_map[i].type; i++) {
        size_t aligned_base = e820_map[i].base - (e820_map[i].base % PAGE_SIZE);
        size_t aligned_length = (e820_map[i].length / PAGE_SIZE) * PAGE_SIZE;
        if (e820_map[i].length % PAGE_SIZE) aligned_length += PAGE_SIZE;
        if (e820_map[i].base % PAGE_SIZE) aligned_length += PAGE_SIZE;

        for (size_t j = 0; j * PAGE_SIZE < aligned_length; j++) {
            size_t addr = aligned_base + j * PAGE_SIZE;

            // Skip over first 4 GiB
            if (addr < 0x100000000)
                continue;

            map_page(kernel_pagemap, MEM_PHYS_OFFSET + addr, addr, 0x03);
        }
    }

    kprint(KPRN_INFO, "vmm: Done.");
    return;
}
