#ifndef CARTRIDGE_H
#define CARTRIDGE_H

#include "../shared/types.h"

typedef struct {
    uint8_t *rom_data;
    size_t rom_size;
} Cartridge;

int cart_load(Cartridge *cart, const char *path);
void cart_unload(Cartridge *cart);

#endif