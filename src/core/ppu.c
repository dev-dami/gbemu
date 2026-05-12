#include "ppu.h"

void ppu_init(PPU *ppu) {
    ppu->lcdc = 0x91;
    ppu->stat = 0x81;
    ppu->scy = 0;
    ppu->scx = 0;
    ppu->ly = 0;
    ppu->lyc = 0;
    ppu->dma = 0;
    for (int i = 0; i < 4; i++) ppu->bgp[i] = 0;
    ppu->wx = 0;
    ppu->wy = 0;
}

void ppu_step(PPU *ppu) {
    (void)ppu;
}