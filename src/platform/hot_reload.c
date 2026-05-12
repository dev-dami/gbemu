#include "../core/gb.h"

void platform_init(void) {}
void platform_poll_events(GameBoy *gb) { (void)gb; }
void platform_render(const uint8_t *framebuffer) { (void)framebuffer; }