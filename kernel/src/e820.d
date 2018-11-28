import klib;

struct e820_entry_t {
    ulong base;
    ulong length;
    uint type;
    uint unused;
}

__gshared e820_entry_t[256] e820_map;

private string e820_type(uint type) {
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

private extern extern (C) void get_e820(e820_entry_t*);

void init_e820() {
    size_t memory_size = 0;

    get_e820(&e820_map[0]);

    // Print out memory map and find total usable memory.
    for (size_t i = 0; e820_map[i].type; i++) {
        kprint(KPRN_INFO, "e820: [%X -> %X] : %X  <%s>", e820_map[i].base,
                                              e820_map[i].base + e820_map[i].length,
                                              e820_map[i].length,
                                              cast(char*)(&e820_type(e820_map[i].type)[0]));
        if (e820_map[i].type == 1) {
            memory_size += e820_map[i].length;
        }
    }

    kprint(KPRN_INFO, "e820: Total usable memory: %U MiB", memory_size / 1024 / 1024);

    return;
}
