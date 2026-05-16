const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;
const Audio = @import("audio.zig").Audio;
const PPU = @import("ppu.zig").PPU;
const Cartridge = @import("cartridge.zig").Cartridge;
const Input = @import("input.zig").Input;
const PPU_WIDTH = @import("ppu.zig").PPU_WIDTH;
const PPU_HEIGHT = @import("ppu.zig").PPU_HEIGHT;

pub const FRAMEBUFFER_SIZE = @as(usize, PPU_WIDTH) * PPU_HEIGHT * 4;

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
    debug: bool = false,
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) GameBoy {
        return .{ .allocator = allocator, .cartridge = Cartridge.init(allocator) };
    }

    pub fn loadRom(self: *GameBoy, io: std.Io, path: []const u8) !void {
        try self.cartridge.load(io, path);
        self.mem.cartridge = &self.cartridge;
        self.mem.timer = &self.timer;
        self.mem.audio = &self.audio;
        self.mem.input = &self.input;
    }

    pub fn unloadRom(self: *GameBoy) void {
        self.cartridge.unload();
        self.mem.cartridge = null;
        self.mem.timer = null;
        self.mem.audio = null;
        self.mem.input = null;
    }

    pub fn step(self: *GameBoy) void {
        self.mem.serial_log = true;
        const cycles = self.cpu.step(&self.mem);
        self.timer.step(cycles, &self.mem.io[0x0F]);
        self.audio.step(cycles);
        self.ppu.step(&self.mem, &self.framebuffer);
        self.input.step(&self.mem.io[0x0F]);
    }
};
