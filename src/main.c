#include "core/gb.h"
#include <stdio.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <rom.gb>\n", argv[0]);
        return 1;
    }
    
    GameBoy gb;
    gb_init(&gb);
    
    if (gb_load_rom(&gb, argv[1]) != 0) {
        printf("Failed to load ROM: %s\n", argv[1]);
        return 1;
    }
    
    printf("ROM loaded, starting emulation...\n");
    printf("Initial PC: 0x%04X\n", gb.cpu.PC);
    
    for (int i = 0; i < 10; i++) {
        gb_step(&gb);
        printf("Step %d, PC: 0x%04X\n", i + 1, gb.cpu.PC);
    }
    
    return 0;
}