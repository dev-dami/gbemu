#include "gb.h"
#include <string.h>

void gb_init(GameBoy *gb) {
    cpu_init(&gb->cpu);
    mem_init(&gb->mem);
    ppu_init(&gb->ppu);
    gb->running = 1;
    memset(gb->framebuffer, 0xFF, sizeof(gb->framebuffer));
}

int gb_load_rom(GameBoy *gb, const char *path) {
    Cartridge cart;
    if (cart_load(&cart, path) != 0) return -1;
    
    size_t copy_size = cart.rom_size < 0x8000 ? cart.rom_size : 0x8000;
    memcpy(gb->mem.rom, cart.rom_data, copy_size);
    
    cart_unload(&cart);
    return 0;
}

void gb_step(GameBoy *gb) {
    cpu_step(&gb->cpu, &gb->mem);
    ppu_step(&gb->ppu);
}