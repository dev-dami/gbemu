# gbemu

A Game Boy emulator written in Zig as a long-term systems programming project.

## Why This Exists

I wanted a project difficult enough to force me to become better at systems programming.

Game Boy emulation touches almost everything I want to improve at: bitwise operations, memory mapping, CPU architecture, state management, debugging, code organization, and platform abstraction. Instead of following a tutorial exactly, I'm building most systems myself and documenting the process as I go.

Originally written in C, the project was rewritten in Zig to take advantage of better type safety, compile-time guarantees, and modern systems programming ergonomics.

## Current State

Implemented:
- ROM loading (cartridge support via `std.Io`)
- CPU with registers (A, F, B, C, D, E, H, L, SP, PC) and 8 opcode implementations
- Memory module with full memory map abstraction
- PPU with scanline rendering, mode stepping, and LCD register support
- Centralized emulator state in a single `GameBoy` struct
- SDL2 platform layer: window, event loop, texture streaming

Working on: PPU stepping refinement, full opcode decode table, actual tile rendering.

Future: timers, interrupts, input handling, audio, MBC support.

## Architecture

All emulator state lives in one `GameBoy` struct:

```zig
pub const GameBoy = struct {
    cpu: CPU = CPU.init(),
    mem: Memory = Memory.init(),
    ppu: PPU = PPU.init(),

    framebuffer: [FRAMEBUFFER_SIZE]u8 = .{0xFF} ** FRAMEBUFFER_SIZE,
    running: bool = true,

    pub fn init() GameBoy { return .{}; }
    pub fn loadRom(self: *GameBoy, io: std.Io, allocator: Allocator, path: []const u8) !void { ... }
    pub fn step(self: *GameBoy) void { ... }
};
```

This centralized design makes the emulation loop trivial—step CPU, step PPU, render frame.

## Project Structure

```
.
├── build.zig          # Zig build configuration
├── build.zig.zon      # Package manifest
├── Makefile           # Convenience wrapper
├── src/
│   ├── main.zig       # Entry point + SDL2 platform layer
│   ├── root.zig       # Public API re-exports
│   └── core/
│       ├── gb.zig     # GameBoy struct (orchestrates all subsystems)
│       ├── cpu.zig    # LR35902 CPU (fetch-decode-execute)
│       ├── memory.zig # Memory map (ROM, VRAM, WRAM, HRAM, IO, OAM)
│       ├── ppu.zig    # Picture Processing Unit (scanline rendering)
│       └── cartridge.zig # ROM loading
```

## Build & Run

### Prerequisites

- Zig 0.16.0+
- SDL2 development libraries

### Commands

```bash
make              # Build (ReleaseFast)
make run <rom.gb> # Build and run
make clean        # Clean build artifacts

# Or with zig directly:
zig build                    # Debug build
zig build -Doptimize=ReleaseFast  # Optimized build
zig build run -- <rom.gb>    # Build and run with args
```

The binary outputs to `zig-out/bin/gameboy`.

## Memory Map

| Range        | Region     | Size   | Access   |
|-------------|------------|--------|----------|
| 0x0000-0x7FFF | ROM       | 32 KB  | Read-only |
| 0x8000-0x9FFF | VRAM      | 8 KB   | Read/Write |
| 0xC000-0xDFFF | WRAM      | 8 KB   | Read/Write |
| 0xE000-0xFDFF | Echo RAM  | 8 KB   | Read/Write (mirrors WRAM) |
| 0xFE00-0xFE9F | OAM       | 160 B  | Read/Write |
| 0xFF00-0xFF7F | IO        | 128 B  | Read/Write |
| 0xFF80-0xFFFE | HRAM      | 127 B  | Read/Write |

## Supported Opcodes

| Opcode | Mnemonic   | Description        |
|--------|------------|--------------------|
| 0x00   | NOP        | No operation       |
| 0x01   | LD BC, d16 | Load immediate 16-bit into BC |
| 0x02   | LD (BC), A | Store A at address BC |
| 0x06   | LD B, d8   | Load immediate into B |
| 0x0E   | LD C, d8   | Load immediate into C |
| 0x3E   | LD A, d8   | Load immediate into A |
| 0xAF   | XOR A      | XOR A with itself (zero A, set Z flag) |
| 0xC3   | JP a16     | Unconditional jump |

## Learning Log

**Day 1**: Got a ROM loading and printing opcodes. The CPU struct was empty, PC just incremented blindly.

**Day 2**: Added actual CPU registers (A, F, B, C, D, E, H, L, SP, PC). Implemented a switch statement for opcodes. JP (0xC3), LD A, n (0x3E), XOR A (0xAF), LD B, n (0x06), LD C, n (0x0E), and LD BC, nn (0x01) work now.

**Day 3**: Refactored memory into its own module. The CPU now reads through an abstraction layer instead of touching raw arrays. Added memory map for ROM, WRAM, HRAM, OAM, and IO registers.

**Day 4**: Added PPU struct with LCDC, STAT, SCY, SCX, LY, LYC, DMA, BGP, OBP, WX, WY registers. Platform stubs for SDL main, event polling, and rendering.

**Day 5**: Implemented SDL2 platform layer - window creation (480x432), event polling, green screen render.

**Day 6**: Rewrote entire project in Zig. Migrated from C to Zig 0.16, replacing manual memory management with Zig's allocators, `std.Io` for file operations, and proper error handling throughout.
