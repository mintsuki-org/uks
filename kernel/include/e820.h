#ifndef __E820_H__
#define __E820_H__

#include <stdint.h>
#include <stddef.h>

struct e820_entry_t {
    uint32_t base;
    uint32_t base_high;
    uint32_t length;
    uint32_t length_high;
    uint32_t type;
    uint32_t unused;
};

extern uint32_t memory_size;
extern struct e820_entry_t e820_map[256];

void init_e820(void);

#endif
