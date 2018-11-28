DC = ldc2
LD = ld
ASM = nasm

D_FILES = $(shell find ./src -type f -name '*.d')
ASM_FILES = $(shell find ./asm -type f -name '*.asm')
REAL_FILES = $(shell find ./real -type f -name '*.real')
OBJ = $(D_FILES:.d=.o) $(ASM_FILES:.asm=.o)
BINS = $(REAL_FILES:.real=.bin)

DHARDFLAGS = -mtriple=x86_64-elf -relocation-model=static -code-model=kernel -mattr=-sse,-sse2 -disable-red-zone -betterC -op -I=./src
LDHARDFLAGS = -nostdlib -T./linker.ld
DFLAGS = -O2
LDFLAGS =

.PHONY: clean

kernel.bin: $(BINS) $(OBJ)
	$(LD) $(LDHARDFLAGS) $(OBJ) $(LDFLAGS) -o $@

%.o: %.d
	$(DC) $(DHARDFLAGS) $(DFLAGS) -c $<

%.o: %.asm
	$(ASM) $< -f elf64 -o $@

%.bin: %.real
	$(ASM) $< -f bin -o $@

clean:
	rm -f $(BINS) $(OBJ) kernel.bin
