const std = @import("std");
const Memory = @import("memory.zig").Memory;

pub const CPU = struct {
    a: u8 = 0,
    f: u8 = 0,
    b: u8 = 0,
    c: u8 = 0,
    d: u8 = 0,
    e: u8 = 0,
    h: u8 = 0,
    l: u8 = 0,

    sp: u16 = 0xFFFE,
    pc: u16 = 0x0100,

    halted: bool = false,
    ime: bool = false,

    pub fn init() CPU {
        return .{};
    }

    // Flag helpers
    pub fn getZ(self: CPU) u8 { return (self.f >> 7) & 1; }
    pub fn getN(self: CPU) u8 { return (self.f >> 6) & 1; }
    pub fn getH(self: CPU) u8 { return (self.f >> 5) & 1; }
    pub fn getC(self: CPU) u8 { return (self.f >> 4) & 1; }

    fn setZ(self: *CPU, v: bool) void { self.f = (self.f & 0x7F) | (if (v) @as(u8, 0x80) else 0); }
    fn setN(self: *CPU, v: bool) void { self.f = (self.f & 0xBF) | (if (v) @as(u8, 0x40) else 0); }
    fn setH(self: *CPU, v: bool) void { self.f = (self.f & 0xDF) | (if (v) @as(u8, 0x20) else 0); }
    fn setC(self: *CPU, v: bool) void { self.f = (self.f & 0xEF) | (if (v) @as(u8, 0x10) else 0); }

    // Register pairs
    pub fn getBC(self: CPU) u16 { return (@as(u16, self.b) << 8) | @as(u16, self.c); }
    pub fn getDE(self: CPU) u16 { return (@as(u16, self.d) << 8) | @as(u16, self.e); }
    pub fn getHL(self: CPU) u16 { return (@as(u16, self.h) << 8) | @as(u16, self.l); }
    pub fn getAF(self: CPU) u16 { return (@as(u16, self.a) << 8) | @as(u16, self.f & 0xF0); }

    pub fn setBC(self: *CPU, v: u16) void { self.b = @truncate(v >> 8); self.c = @truncate(v & 0xFF); }
    pub fn setDE(self: *CPU, v: u16) void { self.d = @truncate(v >> 8); self.e = @truncate(v & 0xFF); }
    pub fn setHL(self: *CPU, v: u16) void { self.h = @truncate(v >> 8); self.l = @truncate(v & 0xFF); }
    pub fn setAF(self: *CPU, v: u16) void { self.a = @truncate(v >> 8); self.f = @truncate(v & 0xF0); }

    fn readPc8(self: *CPU, mem: *const Memory) u8 {
        const val = mem.read(self.pc);
        self.pc +%= 1;
        return val;
    }

    fn readPc16(self: *CPU, mem: *const Memory) u16 {
        const lo = self.readPc8(mem);
        const hi = self.readPc8(mem);
        return (@as(u16, hi) << 8) | @as(u16, lo);
    }

    fn push(self: *CPU, mem: *Memory, val: u16) void {
        self.sp -%= 1;
        mem.write(self.sp, @truncate(val >> 8));
        self.sp -%= 1;
        mem.write(self.sp, @truncate(val & 0xFF));
    }

    fn pop(self: *CPU, mem: *const Memory) u16 {
        const lo = mem.read(self.sp);
        self.sp +%= 1;
        const hi = mem.read(self.sp);
        self.sp +%= 1;
        return (@as(u16, hi) << 8) | @as(u16, lo);
    }

    pub fn step(self: *CPU, mem: *Memory) u8 {
        // ── Interrupt handling ───────────────────────────────────────
        const ie = mem.read(0xFFFF);
        const if_reg = mem.read(0xFF0F);
        const pending = ie & if_reg & 0x1F;

        if (self.ime and pending != 0) {
            var ib: u3 = 0;
            while (ib < 5) : (ib += 1) {
                if ((pending >> ib) & 1 == 1) {
                    self.ime = false;
                    self.halted = false;
                    mem.write(0xFF0F, if_reg & ~(@as(u8, 1) << ib));
                    self.push(mem, self.pc);
                    self.pc = switch (ib) {
                        0 => 0x0040, // VBlank
                        1 => 0x0048, // LCD Stat
                        2 => 0x0050, // Timer
                        3 => 0x0058, // Serial
                        4 => 0x0060, // Joypad
                        else => unreachable,
                    };
                    return 20;
                }
            }
        }

        if (self.halted) {
            if (pending != 0) {
                self.halted = false;
            } else {
                return 4;
            }
        }

        const opcode = self.readPc8(mem);
        var cycles: u8 = 4;

        switch (opcode) {
            0x00 => { cycles = 4; }, // NOP
            0x01 => { self.c = self.readPc8(mem); self.b = self.readPc8(mem); cycles = 12; },
            0x02 => { mem.write(self.getBC(), self.a); cycles = 8; },
            0xC3 => { self.pc = self.readPc16(mem); cycles = 16; },
            0xAF => { self.a = 0; self.f = 0x80; cycles = 4; },
            0x3E => { self.a = self.readPc8(mem); cycles = 8; },
            0x0E => { self.c = self.readPc8(mem); cycles = 8; },
            0x06 => { self.b = self.readPc8(mem); cycles = 8; },
            else => { cycles = 4; },
        }
        return cycles;
    }
};
