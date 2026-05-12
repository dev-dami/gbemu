# gbemu

A Game Boy emulator written in C as a long-term systems programming project.

## Why This Exists

I wanted a project difficult enough to force me to become better at C.

Game Boy emulation touches almost everything I want to improve at: bitwise operations, memory mapping, CPU architecture, state management, debugging, code organization, and platform abstraction. Instead of following a tutorial exactly, I'm building most systems myself and documenting the process as I go.

## Current Goal

Right now the emulator can load ROMs and execute a basic fetch-decode loop with a few supported opcodes. Code size: ~295 LOC total.

Accuracy isn't the priority—learning is. But surprisingly, the code is already shaping up to be pretty accurate anyway.

## Current State

Implemented:
- ROM loading (cartridge support)
- CPU with registers (A, F, B, C, D, E, H, L, SP, PC) and ~10 opcode implementations
- Memory module with read/write abstraction
- PPU struct with LCD registers
- Centralized emulator state in a single `GameBoy` struct
- Modular file layout under `src/core/` and `src/platform/`

Working on: PPU stepping, rendering, full opcode decode table.

Future: timers, interrupts, input handling.

## Architecture

All emulator state lives in one `GameBoy` struct:

```c
typedef struct {
    CPU cpu;
    Memory mem;
    PPU ppu;
    uint8_t framebuffer[160 * 144 * 4];
    int running;
} GameBoy;
```

This centralized design makes hot reloading trivial—swap out the core while keeping the outer loop running.

## Build & Run

```bash
make       # builds to builds/gameboy
./builds/gameboy <rom.gb>
```

Test ROM included at `builds/test.gb`.

## Learning Log

**Day 1**: Got a ROM loading and printing opcodes. The CPU struct was empty, PC just incremented blindly.

**Day 2**: Added actual CPU registers (A, F, B, C, D, E, H, L, SP, PC). Implemented a switch statement for opcodes. JP (0xC3), LD A, n (0x3E), XOR A (0xAF), LD B, n (0x06), LD C, n (0x0E), and LD BC, nn (0x01) work now.

**Day 3**: Refactored memory into its own module. The CPU now reads through an abstraction layer instead of touching raw arrays. Added memory map for ROM, WRAM, HRAM, OAM, and IO registers.

**Day 4**: Added PPU struct with LCDC, STAT, SCY, SCX, LY, LYC, DMA, BGP, OBP, WX, WY registers. Platform stubs for SDL main, event polling, and rendering.

Next: decode table for all ~500 opcodes, then rendering so we can see something.