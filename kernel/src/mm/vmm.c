#include <stdint.h>
#include <stddef.h>
#include <mm.h>
#include <klib.h>

/* map physaddr -> virtaddr using pd pointer */
void map_page(pt_entry_t *pd, size_t phys_addr, size_t virt_addr, size_t flags) {
    /* Calculate the indices in the various tables using the virtual address */
    size_t i;

    size_t pd_entry = (virt_addr & ((size_t)0x3ff << 22)) >> 22;
    size_t pt_entry = (virt_addr & ((size_t)0x3ff << 12)) >> 12;

    pt_entry_t *pt;

    if (pd[pd_entry] & 0x1) {
        pt = (pt_entry_t *)(pd[pd_entry] & 0xfffff000);
    } else {
        /* Allocate a page for the pt. */
        pt = pmm_alloc(1);

        /* Zero page */
        for (i = 0; i < PAGE_TABLE_ENTRIES; i++) {
            /* Zero each entry */
            pt[i] = 0;
        }

        /* Present + writable + user (0b111) */
        pd[pd_entry] = (pt_entry_t)pt | 0x07;
    }

    /* Set the entry as present and point it to the passed physical address */
    /* Also set the specified flags */
    pt[pt_entry] = (pt_entry_t)(phys_addr | flags);
    return;
}

int unmap_page(pt_entry_t *pd, size_t virt_addr) {
    /* Calculate the indices in the various tables using the virtual address */
    size_t pd_entry = (virt_addr & ((size_t)0x3ff << 22)) >> 22;
    size_t pt_entry = (virt_addr & ((size_t)0x3ff << 12)) >> 12;

    pt_entry_t *pt;

    /* Get reference to the various tables in sequence. Return -1 if one of the tables is not present,
     * since we cannot unmap a virtual address if we don't know what it's mapped to in the first place */
    if (pd[pd_entry] & 0x1) {
        pt = (pt_entry_t *)(pd[pd_entry] & 0xfffff000);
    } else {
        return -1;
    }

    /* Unmap entry */
    pt[pt_entry] = 0;

    return 0;
}

/* Update flags for a mapping */
int remap_page(pt_entry_t *pd, size_t virt_addr, size_t flags) {
    /* Calculate the indices in the various tables using the virtual address */
    size_t pd_entry = (virt_addr & ((size_t)0x3ff << 22)) >> 22;
    size_t pt_entry = (virt_addr & ((size_t)0x3ff << 12)) >> 12;

    pt_entry_t *pt;

    /* Get reference to the various tables in sequence. Return -1 if one of the tables is not present,
     * since we cannot unmap a virtual address if we don't know what it's mapped to in the first place */
    if (pd[pd_entry] & 0x1) {
        pt = (pt_entry_t *)(pd[pd_entry] & 0xfffff000);
    } else {
        return -1;
    }

    /* Update flags */
    pt[pt_entry] = (pt[pt_entry] & 0xfffff000) | flags;

    return 0;
}

/* Identity map the first 4GiB of memory, this saves issues with MMIO hardware < 4GiB later on */
void init_vmm(void) {
    size_t i;

    kprint(KPRN_INFO, "vmm: Identity mapping memory for the kernel...");

    for (i = 0; i < (0x100000000 / PAGE_SIZE); i++) {
        size_t addr = i * PAGE_SIZE;
        map_page(kernel_pagemap, addr, addr, 0x03);
    }

    kprint(KPRN_INFO, "vmm: Done");

    return;
}
