CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -I.
SRCS = src/main.c src/core/gb.c src/core/cpu.c src/core/memory.c src/core/ppu.c src/core/cartridge.c
LIBS = -lm
BUILD_DIR = builds

gameboy: $(SRCS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $(BUILD_DIR)/$@ $^ $(LIBS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean