#include "memory.h"

void mem_init(Memory *mem) {
    for (int i = 0; i < 0x8000; i++) mem->rom[i] = 0;
    for (int i = 0; i < 0x2000; i++) mem->wram[i] = 0;
    for (int i = 0; i < 0x7F; i++) mem->hram[i] = 0;
    for (int i = 0; i < 0x80; i++) mem->io[i] = 0;
    for (int i = 0; i < 0xA0; i++) mem->oam[i] = 0;
}

uint8_t mem_read(Memory *mem, uint16_t addr) {
    if (addr < 0x8000) return mem->rom[addr];
    if (addr >= 0xC000 && addr < 0xE000) return mem->wram[addr - 0xC000];
    if (addr >= 0xFF80) return mem->hram[addr - 0xFF80];
    if (addr >= 0xFE00 && addr < 0xFEA0) return mem->oam[addr - 0xFE00];
    return 0xFF;
}

void mem_write(Memory *mem, uint16_t addr, uint8_t val) {
    if (addr < 0x8000) return;
    if (addr >= 0xC000 && addr < 0xE000) mem->wram[addr - 0xC000] = val;
    else if (addr >= 0xFF80) mem->hram[addr - 0xFF80] = val;
    else if (addr >= 0xFE00 && addr < 0xFEA0) mem->oam[addr - 0xFE00] = val;
}