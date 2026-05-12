#include "cartridge.h"
#include <stdio.h>
#include <stdlib.h>

int cart_load(Cartridge *cart, const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    
    fseek(f, 0, SEEK_END);
    cart->rom_size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    cart->rom_data = malloc(cart->rom_size);
    if (!cart->rom_data) {
        fclose(f);
        return -1;
    }
    
    fread(cart->rom_data, 1, cart->rom_size, f);
    fclose(f);
    return 0;
}

void cart_unload(Cartridge *cart) {
    free(cart->rom_data);
    cart->rom_data = NULL;
    cart->rom_size = 0;
}