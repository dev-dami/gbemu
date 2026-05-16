const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;
const PPU = @import("ppu.zig").PPU;
const Cartridge = @import("cartridge.zig").Cartridge;
const PPU_WIDTH = @import("ppu.zig").PPU_WIDTH;
const PPU_HEIGHT = @import("ppu.zig").PPU_HEIGHT;

pub const FRAMEBUFFER_SIZE = @as(usize, PPU_WIDTH) * PPU_HEIGHT * 4;

pub const GameBoy = struct {
    cpu: CPU = CPU.init(),
    mem: Memory = Memory.init(),
    ppu: PPU = PPU.init(),

    framebuffer: [FRAMEBUFFER_SIZE]u8 = .{0xFF} ** FRAMEBUFFER_SIZE,

    running: bool = true,

    pub fn init() GameBoy {
        return .{};
    }

    pub fn loadRom(self: *GameBoy, io: std.Io, allocator: std.mem.Allocator, path: []const u8) !void {
        var cart = Cartridge.init(allocator);
        defer cart.unload();

        try cart.load(io, path);

        const rom_data = cart.rom_data orelse return error.NoRomData;
        const copy_size = @min(rom_data.len, 0x8000);
        @memcpy(self.mem.rom[0..copy_size], rom_data[0..copy_size]);
    }

    pub fn step(self: *GameBoy) void {
        self.cpu.step(&self.mem);
        self.ppu.step(&self.mem, &self.framebuffer);
    }
};
