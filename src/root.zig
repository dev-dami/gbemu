//! Game Boy emulator - core library root.
//! This file re-exports the public API for use as a library.

pub const CPU = @import("core/cpu.zig").CPU;
pub const Memory = @import("core/memory.zig").Memory;
pub const PPU = @import("core/ppu.zig").PPU;
pub const Cartridge = @import("core/cartridge.zig").Cartridge;
pub const GameBoy = @import("core/gb.zig").GameBoy;

pub const FRAMEBUFFER_SIZE = @import("core/gb.zig").FRAMEBUFFER_SIZE;
pub const PPU_WIDTH = @import("core/ppu.zig").PPU_WIDTH;
pub const PPU_HEIGHT = @import("core/ppu.zig").PPU_HEIGHT;
