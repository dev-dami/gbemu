CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -I. $(shell pkg-config --cflags sdl2)
SRCS = src/platform/sdl_main.c src/platform/hot_reload.c src/core/gb.c src/core/cpu.c src/core/memory.c src/core/ppu.c src/core/cartridge.c
LIBS = $(shell pkg-config --libs sdl2) -lm
BUILD_DIR = builds

gameboy: $(SRCS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $(BUILD_DIR)/$@ $^ $(LIBS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean