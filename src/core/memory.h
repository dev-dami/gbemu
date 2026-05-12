#ifndef MEMORY_H
#define MEMORY_H

#include "../shared/types.h"

typedef struct {
    uint8_t rom[0x8000];
    uint8_t wram[0x2000];
    uint8_t hram[0x7F];
    uint8_t io[0x80];
    uint8_t oam[0xA0];
} Memory;

void mem_init(Memory *mem);
uint8_t mem_read(Memory *mem, uint16_t addr);
void mem_write(Memory *mem, uint16_t addr, uint8_t val);

#endif