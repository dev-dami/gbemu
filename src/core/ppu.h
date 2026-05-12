#ifndef PPU_H
#define PPU_H

#include "../shared/types.h"

typedef struct {
    uint8_t lcdc;
    uint8_t stat;
    uint8_t scy;
    uint8_t scx;
    uint8_t ly;
    uint8_t lyc;
    uint8_t dma;
    uint8_t bgp[4];
    uint8_t obp[2][4];
    uint8_t wx;
    uint8_t wy;
} PPU;

void ppu_init(PPU *ppu);
void ppu_step(PPU *ppu);

#endif