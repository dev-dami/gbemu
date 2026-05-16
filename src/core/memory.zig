const std = @import("std");
const Cartridge = @import("cartridge.zig").Cartridge;
const Timer = @import("timer.zig").Timer;
const Audio = @import("audio.zig").Audio;
const Input = @import("input.zig").Input;

pub const Memory = struct {
    cartridge: ?*Cartridge = null,
    timer: ?*Timer = null,
    audio: ?*Audio = null,
    input: ?*Input = null,
    vram: [0x2000]u8 = .{0} ** 0x2000,
    wram: [0x2000]u8 = .{0} ** 0x2000,
    hram: [0x80]u8 = .{0} ** 0x80,
    io: [0x80]u8 = .{0} ** 0x80,
    oam: [0xA0]u8 = .{0} ** 0xA0,
    serial_log: bool = false,

    pub fn init() Memory {
        return .{};
    }

    pub fn read(self: *const Memory, addr: u16) u8 {
        if (addr < 0x8000) {
            if (self.cartridge) |cart| {
                return cart.readRom(addr);
            }
            return 0xFF;
        }
        if (addr >= 0x8000 and addr < 0xA000) return self.vram[addr - 0x8000];
        if (addr >= 0xA000 and addr < 0xC000) {
            if (self.cartridge) |cart| {
                return cart.readRam(addr);
            }
            return 0xFF;
        }
        if (addr >= 0xC000 and addr < 0xE000) return self.wram[addr - 0xC000];
        if (addr >= 0xE000 and addr < 0xFE00) return self.wram[addr - 0xE000]; // echo RAM
        if (addr >= 0xFE00 and addr < 0xFEA0) return self.oam[addr - 0xFE00];
        if (addr >= 0xFF00 and addr < 0xFF80) {
            // Input IO delegation
            if (addr == 0xFF00) {
                if (self.input) |input| {
                    return input.read(addr);
                }
            }
            // Timer IO delegation
            if (addr >= 0xFF04 and addr <= 0xFF07) {
                if (self.timer) |timer| {
                    return timer.read(addr);
                }
            }
            // Audio IO delegation
            if (addr >= 0xFF10 and addr <= 0xFF3F) {
                if (self.audio) |audio| {
                    return audio.read(addr);
                }
            }
            return self.io[addr - 0xFF00];
        }
        if (addr >= 0xFF80) return self.hram[addr - 0xFF80];
        return 0xFF;
    }

    pub fn write(self: *Memory, addr: u16, val: u8) void {
        if (addr < 0x8000) {
            if (self.cartridge) |cart| {
                cart.writeRom(addr, val);
            }
            return;
        }
        if (addr >= 0x8000 and addr < 0xA000) {
            self.vram[addr - 0x8000] = val;
            return;
        }
        if (addr >= 0xA000 and addr < 0xC000) {
            if (self.cartridge) |cart| {
                cart.writeRam(addr, val);
            }
            return;
        }
        if (addr >= 0xC000 and addr < 0xE000) {
            self.wram[addr - 0xC000] = val;
            return;
        }
        if (addr >= 0xE000 and addr < 0xFE00) {
            self.wram[addr - 0xE000] = val; // echo RAM
            return;
        }
        if (addr >= 0xFE00 and addr < 0xFEA0) {
            self.oam[addr - 0xFE00] = val;
            return;
        }
        if (addr >= 0xFF00 and addr < 0xFF80) {
            // Input IO delegation
            if (addr == 0xFF00) {
                if (self.input) |input| {
                    input.write(addr, val);
                    return;
                }
            }
            // Timer IO delegation
            if (addr >= 0xFF04 and addr <= 0xFF07) {
                if (self.timer) |timer| {
                    var if_reg = self.io[0x0F];
                    timer.write(addr, val, &if_reg);
                    self.io[0x0F] = if_reg;
                    return;
                }
            }
            // Audio IO delegation
            if (addr >= 0xFF10 and addr <= 0xFF3F) {
                if (self.audio) |audio| {
                    audio.write(addr, val);
                    return;
                }
            }
            // Serial port: capture output when SC (0xFF02) is written with bit 7 set
            if (addr == 0xFF02 and (val & 0x80) != 0 and self.serial_log) {
                const sb = self.io[0x01]; // SB register
                if (sb >= 0x20 and sb < 0x7F) {
                    std.debug.print("{c}", .{sb});
                } else if (sb == 0x0A or sb == 0x0D) {
                    std.debug.print("\n", .{});
                }
            }
            self.io[addr - 0xFF00] = val;
            return;
        }
        if (addr >= 0xFF80) {
            self.hram[addr - 0xFF80] = val;
            return;
        }
    }
};
