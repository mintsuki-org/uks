#include <stdint.h>
#include <stddef.h>
#include <e820.h>
#include <klib.h>

uint32_t memory_size = 0;

struct e820_entry_t e820_map[256];

static char *e820_type(uint32_t type) {
    switch (type) {
        case 1:
            return "Usable RAM";
        case 2:
            return "Reserved";
        case 3:
            return "ACPI reclaimable";
        case 4:
            return "ACPI NVS";
        case 5:
            return "Bad memory";
        default:
            return "???";
    }
}

void init_e820(void) {
    size_t i;

    /* Print out memory map and find total usable memory. */
    for (i = 0; e820_map[i].type; i++) {
        if (e820_map[i].base_high || e820_map[i].length_high) {
            continue;
        }
        if (e820_map[i].base + e820_map[i].length < e820_map[i].base) {
            /* overflow check */
            continue;
        }
        kprint(KPRN_INFO, "e820: [%x -> %x] : %x  <%s>", e820_map[i].base,
                                              e820_map[i].base + e820_map[i].length,
                                              e820_map[i].length,
                                              e820_type(e820_map[i].type));
        if (e820_map[i].type == 1) {
            memory_size += e820_map[i].length;
        }
    }

    kprint(KPRN_INFO, "e820: Total usable memory: %u MiB", memory_size / 1024 / 1024);

    return;
}
