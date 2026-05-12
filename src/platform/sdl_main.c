#include "../core/gb.h"
#include <stdio.h>

void platform_init(void);
void platform_poll_events(GameBoy *gb);
void platform_render(const uint8_t *framebuffer);

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <rom.gb>\n", argv[0]);
        return 1;
    }
    
    platform_init();
    
    GameBoy gb;
    gb_init(&gb);
    
    if (gb_load_rom(&gb, argv[1]) != 0) {
        printf("Failed to load ROM: %s\n", argv[1]);
        return 1;
    }
    
    printf("ROM loaded, starting emulation...\n");
    printf("Initial PC: 0x%04X\n", gb.cpu.PC);
    
    while (gb.running) {
        gb_step(&gb);
        platform_poll_events(&gb);
        platform_render(gb.framebuffer);
    }
    
    return 0;
}