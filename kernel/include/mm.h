#ifndef __MM_H__
#define __MM_H__

#include <stddef.h>
#include <stdint.h>

#define PAGE_SIZE 4096

#define PAGE_TABLE_ENTRIES 1024

typedef uint32_t pt_entry_t;

extern pt_entry_t kernel_pagemap;

void *pmm_alloc(size_t);
void pmm_free(void *, size_t);
void init_pmm(void);

void map_page(pt_entry_t *, size_t, size_t, size_t);
int unmap_page(pt_entry_t *, size_t);
int remap_page(pt_entry_t *, size_t, size_t);
void init_vmm(void);

#endif
