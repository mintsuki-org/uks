CC = bcc
LD = ld86
ASM = nasm

C_FILES = $(shell find ./src -type f -name '*.c')
H_FILES = $(shell find ./include -type f -name '*.h')
ASM_FILES = $(shell find ./asm -type f -name '*.asm')
REAL_FILES = $(shell find ./real -type f -name '*.real')
STARTUP_FILES = $(shell find ./startup -type f -name '*.asm')
OBJ = $(STARTUP_FILES:.asm=.o) $(C_FILES:.c=.o) $(ASM_FILES:.asm=.o)
BINS = $(REAL_FILES:.real=.bin)

CHARDFLAGS = -3 -ansi -I./include/
LDHARDFLAGS = -d -T0x100000
CFLAGS = 
LDFLAGS = 

.PHONY: clean

kernel.bin: $(BINS) $(OBJ) $(H_FILES)
	$(LD) $(LDHARDFLAGS) $(OBJ) $(LDFLAGS) -o $@

%.o: %.c
	$(CC) $(CHARDFLAGS) $(CFLAGS) -c $< -o $@

%.o: %.asm
	$(ASM) $< -f as86 -o $@

%.bin: %.real
	$(ASM) $< -f bin -o $@

clean:
	rm -f $(BINS) $(OBJ) kernel.bin
