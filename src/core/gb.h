#ifndef GB_H
#define GB_H

#include "../shared/types.h"
#include "cpu.h"
#include "memory.h"
#include "ppu.h"
#include "cartridge.h"

typedef struct {
    CPU cpu;
    Memory mem;
    PPU ppu;
    
    uint8_t framebuffer[160 * 144 * 4];
    
    int running;
} GameBoy;

void gb_init(GameBoy *gb);
int gb_load_rom(GameBoy *gb, const char *path);
void gb_step(GameBoy *gb);

#endif