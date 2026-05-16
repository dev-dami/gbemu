# gbemu

A Game Boy emulator written in Zig as a long-term systems programming project.

## Why This Exists

I wanted a project difficult enough to force me to become better at systems programming.

Game Boy emulation touches almost everything I want to improve at: bitwise operations, memory mapping, CPU architecture, state management, debugging, code organization, and platform abstraction. Instead of following a tutorial exactly, I'm building most systems myself and documenting the process as I go.

Originally written in C, the project was rewritten in Zig to take advantage of better type safety, compile-time guarantees, and modern systems programming ergonomics.

## Current State

Implemented:
- **CPU**: Full LR35902 instruction set (256 main + 256 CB prefix opcodes) with cycle counting
- **Interrupts**: IME, IE/IF registers, VBlank/LCD/Timer/Serial/Joypad vector dispatch
- **Cartridge**: MBC1/MBC5 ROM banking, external RAM allocation, cartridge type detection
- **Memory**: Full memory map with IO delegation to subsystems
- **PPU**: Scanline rendering, mode stepping (OAM/Transfer/HBlank/VBlank), LCD register sync
- **Timer**: DIV, TIMA, TMA, TAC registers with overflow interrupts
- **Audio**: 4 sound channels (Square 1/2, Wave, Noise) with master volume control
- **Input**: SDL2 keyboard mapping, JOY register (0xFF00), button interrupt handling
- **Platform**: SDL2 window, event loop, texture streaming, headless test mode (`--steps N`)

Working on: Full PPU tile rendering, MBC2/MBC3 support, audio output via SDL2, save states.

## Architecture

All emulator state lives in one `GameBoy` struct:

```zig
pub const GameBoy = struct {
    cpu: CPU = CPU.init(),
    mem: Memory = Memory.init(),
    timer: Timer = Timer.init(),
    audio: Audio = Audio.init(),
    ppu: PPU = PPU.init(),
    input: Input = Input.init(),
    cartridge: Cartridge = undefined,

    framebuffer: [FRAMEBUFFER_SIZE]u8 = .{0xFF} ** FRAMEBUFFER_SIZE,
    running: bool = true,

    pub fn init(allocator: std.mem.Allocator) GameBoy { ... }
    pub fn loadRom(self: *GameBoy, io: std.Io, path: []const u8) !void { ... }
    pub fn step(self: *GameBoy) void { ... }
};
```

This centralized design makes the emulation loop trivial—step CPU, step timer, step audio, step PPU, poll input.

## Project Structure

```
.
├── build.zig          # Zig build configuration
├── build.zig.zon      # Package manifest
├── Makefile           # Convenience wrapper
├── roms/              # Legal test ROMs
│   ├── cpu_instrs.gb  # Blargg CPU test suite
│   ├── dmg-acid2.gb   # PPU accuracy test
│   ├── 01-special.gb  # Special instruction test
│   ├── instr_timing.gb # Instruction timing test
│   ├── porklike.gb    # MBC1 homebrew roguelike
│   └── tellinglys.gb  # ROM-only homebrew game
├── src/
│   ├── main.zig       # Entry point + SDL2 platform layer
│   ├── root.zig       # Public API re-exports
│   └── core/
│       ├── gb.zig     # GameBoy struct (orchestrates all subsystems)
│       ├── cpu.zig    # LR35902 CPU (full instruction set + cycle counting)
│       ├── memory.zig # Memory map with IO delegation
│       ├── ppu.zig    # Picture Processing Unit (scanline rendering)
│       ├── cartridge.zig # MBC1/MBC5 banking + external RAM
│       ├── timer.zig  # DIV/TIMA/TMA/TAC timer subsystem
│       ├── audio.zig  # 4-channel audio (Square/Wave/Noise)
│       └── input.zig  # JOY register + button mapping
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

Full LR35902 instruction set implemented:

| Category | Opcodes | Description |
|----------|---------|-------------|
| 8-bit loads | 0x40-0x7F, 0x06/0x0E/0x16/0x1E/0x26/0x2E/0x3E | LD r,r' / LD r,d8 / LD r,(HL) / LD (HL),r |
| 16-bit loads | 0x01/0x11/0x21/0x31, 0xF9, 0xF8, 0xEA/0xFA, 0x0A/0x1A, 0x02/0x12 | LD rr,d16 / LD SP,HL / LD HL,SP+e8 / LD (a16),A |
| Stack | 0xF5/0xC5/0xD5/0xE5, 0xF1/0xC1/0xD1/0xE1 | PUSH rr / POP rr |
| 8-bit ALU | 0x80-0xBF, 0xC6/0xCE/0xD6/0xDE/0xE6/0xF6/0xEE/0xFE | ADD/ADC/SUB/SBC/AND/OR/XOR/CP |
| INC/DEC | 0x04/0x0C/0x14/0x1C/0x24/0x2C/0x3C, 0x34, 0x05/0x0D/.../0x3D, 0x35 | INC r / INC (HL) / DEC r / DEC (HL) |
| 16-bit ALU | 0x09/0x19/0x29/0x39, 0x03/0x13/0x23/0x33, 0x0B/0x1B/0x2B/0x3B | ADD HL,rr / INC rr / DEC rr |
| Rotates | 0x07/0x0F/0x17/0x1F | RLCA/RRCA/RLA/RRA |
| Jumps | 0xC3, 0xC2/0xCA/0xD2/0xDA, 0xE9, 0x18, 0x20/0x28/0x30/0x38 | JP / JP cond / JP (HL) / JR / JR cond |
| Calls | 0xCD, 0xC4/0xCC/0xD4/0xDC | CALL / CALL cond |
| Returns | 0xC9, 0xC0/0xC8/0xD0/0xD8, 0xD9 | RET / RET cond / RETI |
| Restarts | 0xC7/0xCF/0xD7/0xDF/0xE7/0xEF/0xF7/0xFF | RST 00/08/10/18/20/28/30/38 |
| CB prefix | 0x00-0x3F, 0x40-0x7F, 0x80-0xBF, 0xC0-0xFF | RLC/RRC/RL/RR/SLA/SRA/SRL/SWAP/BIT/RES/SET |
| Control | 0x00, 0x76, 0x10, 0xF3, 0xFB, 0x27, 0x2F, 0x3F, 0x37 | NOP/HALT/STOP/DI/EI/DAA/CPL/CCF/SCF |

## Learning Log

**Day 1**: Got a ROM loading and printing opcodes. The CPU struct was empty, PC just incremented blindly.

**Day 2**: Added actual CPU registers (A, F, B, C, D, E, H, L, SP, PC). Implemented a switch statement for opcodes. JP (0xC3), LD A, n (0x3E), XOR A (0xAF), LD B, n (0x06), LD C, n (0x0E), and LD BC, nn (0x01) work now.

**Day 3**: Refactored memory into its own module. The CPU now reads through an abstraction layer instead of touching raw arrays. Added memory map for ROM, WRAM, HRAM, OAM, and IO registers.

**Day 4**: Added PPU struct with LCDC, STAT, SCY, SCX, LY, LYC, DMA, BGP, OBP, WX, WY registers. Platform stubs for SDL main, event polling, and rendering.

**Day 5**: Implemented SDL2 platform layer - window creation (480x432), event polling, green screen render.

**Day 6**: Rewrote entire project in Zig. Migrated from C to Zig 0.16, replacing manual memory management with Zig's allocators, `std.Io` for file operations, and proper error handling throughout.

**Day 7**: Implemented full CPU instruction set (256 main + 256 CB prefix opcodes), interrupt handling, timer subsystem (DIV/TIMA/TMA/TAC), audio subsystem (4 channels), input handling (SDL2 keyboard mapping), and MBC1/MBC5 cartridge banking. Memory IO delegation routes reads/writes to appropriate subsystems. Blargg cpu_instrs passes tests 01-02, dmg-acid2 completes and halts, 01-special passes.

**Day 8**: Full 20-commit implementation session. All major subsystems integrated: CPU with cycle counting, MBC banking for ROM-only and MBC1/MBC5 cartridges, timer with overflow interrupts, audio with 4 sound channels, and SDL2 input mapping. Verified against legal test ROMs.

## Test Results

| ROM | Status | Notes |
|-----|--------|-------|
| **01-special.gb** | ✅ Passes | All special instruction tests pass |
| **dmg-acid2.gb** | ✅ Completes | PPU accuracy test halts successfully |
| **tellinglys.gb** | ✅ Runs | ROM-only homebrew game |
| **cpu_instrs.gb** | ⚠️ 01-02 pass | Tests 03+ need debugging |
| **instr_timing.gb** | ❌ Fails #255 | Cycle timing needs tuning |
| **porklike.gb** | ❌ Stuck at 0x0038 | VBlank ISR issue (MBC1 game) |

## Controls

| Key | Game Boy Button |
|-----|----------------|
| Arrow Keys | D-Pad (Up/Down/Left/Right) |
| Z | A |
| X | B |
| Enter | Start |
| Space | Select |
| Escape | Quit |
