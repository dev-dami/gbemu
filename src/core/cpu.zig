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
                    return 20; // Interrupt takes 20 cycles
                }
            }
        }

        if (self.halted) {
            if (pending != 0) {
                self.halted = false;
            } else {
                return 4; // HALT: 4 cycles per step
            }
        }

        const opcode = self.readPc8(mem);
        var cycles: u8 = 4;

        switch (opcode) {
            // ── 8-bit loads: LD r, r' ────────────────────────────────
            0x7F => { self.a = self.a; }, // LD A, A
            0x78 => { self.a = self.b; }, // LD A, B
            0x79 => { self.a = self.c; }, // LD A, C
            0x7A => { self.a = self.d; }, // LD A, D
            0x7B => { self.a = self.e; }, // LD A, E
            0x7C => { self.a = self.h; }, // LD A, H
            0x7D => { self.a = self.l; }, // LD A, L
            0x7E => { self.a = mem.read(self.getHL()); }, // LD A, (HL)

            0x47 => { self.b = self.a; }, // LD B, A
            0x40 => { self.b = self.b; }, // LD B, B
            0x41 => { self.b = self.c; }, // LD B, C
            0x42 => { self.b = self.d; }, // LD B, D
            0x43 => { self.b = self.e; }, // LD B, E
            0x44 => { self.b = self.h; }, // LD B, H
            0x45 => { self.b = self.l; }, // LD B, L
            0x46 => { self.b = mem.read(self.getHL()); }, // LD B, (HL)

            0x4F => { self.c = self.a; }, // LD C, A
            0x48 => { self.c = self.b; }, // LD C, B
            0x49 => { self.c = self.c; }, // LD C, C
            0x4A => { self.c = self.d; }, // LD C, D
            0x4B => { self.c = self.e; }, // LD C, E
            0x4C => { self.c = self.h; }, // LD C, H
            0x4D => { self.c = self.l; }, // LD C, L
            0x4E => { self.c = mem.read(self.getHL()); }, // LD C, (HL)

            0x57 => { self.d = self.a; }, // LD D, A
            0x50 => { self.d = self.b; }, // LD D, B
            0x51 => { self.d = self.c; }, // LD D, C
            0x52 => { self.d = self.d; }, // LD D, D
            0x53 => { self.d = self.e; }, // LD D, E
            0x54 => { self.d = self.h; }, // LD D, H
            0x55 => { self.d = self.l; }, // LD D, L
            0x56 => { self.d = mem.read(self.getHL()); }, // LD D, (HL)

            0x5F => { self.e = self.a; }, // LD E, A
            0x58 => { self.e = self.b; }, // LD E, B
            0x59 => { self.e = self.c; }, // LD E, C
            0x5A => { self.e = self.d; }, // LD E, D
            0x5B => { self.e = self.e; }, // LD E, E
            0x5C => { self.e = self.h; }, // LD E, H
            0x5D => { self.e = self.l; }, // LD E, L
            0x5E => { self.e = mem.read(self.getHL()); }, // LD E, (HL)

            0x67 => { self.h = self.a; }, // LD H, A
            0x60 => { self.h = self.b; }, // LD H, B
            0x61 => { self.h = self.c; }, // LD H, C
            0x62 => { self.h = self.d; }, // LD H, D
            0x63 => { self.h = self.e; }, // LD H, E
            0x64 => { self.h = self.h; }, // LD H, H
            0x65 => { self.h = self.l; }, // LD H, L
            0x66 => { self.h = mem.read(self.getHL()); }, // LD H, (HL)

            0x6F => { self.l = self.a; }, // LD L, A
            0x68 => { self.l = self.b; }, // LD L, B
            0x69 => { self.l = self.c; }, // LD L, C
            0x6A => { self.l = self.d; }, // LD L, D
            0x6B => { self.l = self.e; }, // LD L, E
            0x6C => { self.l = self.h; }, // LD L, H
            0x6D => { self.l = self.l; }, // LD L, L
            0x6E => { self.l = mem.read(self.getHL()); }, // LD L, (HL)

            // LD r, d8
            0x3E => { self.a = self.readPc8(mem); },
            0x06 => { self.b = self.readPc8(mem); },
            0x0E => { self.c = self.readPc8(mem); },
            0x16 => { self.d = self.readPc8(mem); },
            0x1E => { self.e = self.readPc8(mem); },
            0x26 => { self.h = self.readPc8(mem); },
            0x2E => { self.l = self.readPc8(mem); },

            // LD (HL), r
            0x77 => { mem.write(self.getHL(), self.a); },
            0x70 => { mem.write(self.getHL(), self.b); },
            0x71 => { mem.write(self.getHL(), self.c); },
            0x72 => { mem.write(self.getHL(), self.d); },
            0x73 => { mem.write(self.getHL(), self.e); },
            0x74 => { mem.write(self.getHL(), self.h); },
            0x75 => { mem.write(self.getHL(), self.l); },

            // LD (HL), d8
            0x36 => {
                const val = self.readPc8(mem);
                mem.write(self.getHL(), val);
            },

            // LD A, (BC), LD A, (DE)
            0x0A => { self.a = mem.read(self.getBC()); },
            0x1A => { self.a = mem.read(self.getDE()); },

            // LD (BC), A, LD (DE), A
            0x02 => { mem.write(self.getBC(), self.a); },
            0x12 => { mem.write(self.getDE(), self.a); },

            // LD A, (a16), LD (a16), A
            0xFA => {
                const addr = self.readPc16(mem);
                self.a = mem.read(addr);
            },
            0xEA => {
                const addr = self.readPc16(mem);
                mem.write(addr, self.a);
            },

            // LD A, (0xFF00 + a8), LD (0xFF00 + a8), A
            0xF0 => {
                const addr = @as(u16, 0xFF00) | @as(u16, self.readPc8(mem));
                self.a = mem.read(addr);
            },
            0xE0 => {
                const addr = @as(u16, 0xFF00) | @as(u16, self.readPc8(mem));
                mem.write(addr, self.a);
            },

            // LD A, (0xFF00 + C), LD (0xFF00 + C), A
            0xF2 => { self.a = mem.read(@as(u16, 0xFF00) | @as(u16, self.c)); },
            0xE2 => { mem.write(@as(u16, 0xFF00) | @as(u16, self.c), self.a); },

            // LD (C), A  (same as E2)
            // Already handled above

            // LDI (HL), A / LD A, (HL+)
            0x22 => {
                mem.write(self.getHL(), self.a);
                self.setHL(self.getHL() +% 1);
            },
            0x2A => {
                self.a = mem.read(self.getHL());
                self.setHL(self.getHL() +% 1);
            },

            // LDD (HL), A / LD A, (HL-)
            0x32 => {
                mem.write(self.getHL(), self.a);
                self.setHL(self.getHL() -% 1);
            },
            0x3A => {
                self.a = mem.read(self.getHL());
                self.setHL(self.getHL() -% 1);
            },

            // ── 16-bit loads ─────────────────────────────────────────
            0x01 => {
                self.c = self.readPc8(mem);
                self.b = self.readPc8(mem);
            },
            0x11 => {
                self.e = self.readPc8(mem);
                self.d = self.readPc8(mem);
            },
            0x21 => {
                self.l = self.readPc8(mem);
                self.h = self.readPc8(mem);
            },
            0x31 => {
                const lo = self.readPc8(mem);
                const hi = self.readPc8(mem);
                self.sp = (@as(u16, hi) << 8) | @as(u16, lo);
            },

            // LD SP, HL
            0xF9 => {
                self.sp = self.getHL();
            },

            // LD HL, SP + e8
            0xF8 => {
                const offset: i8 = @bitCast(self.readPc8(mem));
                const sp = self.sp;
                const result: u16 = sp +% @as(u16, @bitCast(@as(i16, offset)));
                self.setHL(result);
                self.setZ(false);
                self.setN(false);
                self.setH(((sp & 0x0F) +% (@as(u8, @bitCast(offset)) & 0x0F)) > 0x0F);
                self.setC(((sp & 0xFF) +% (@as(u8, @bitCast(offset)) & 0xFF)) > 0xFF);
            },

            // PUSH / POP
            0xF5 => { self.push(mem, self.getAF()); },
            0xC5 => { self.push(mem, self.getBC()); },
            0xD5 => { self.push(mem, self.getDE()); },
            0xE5 => { self.push(mem, self.getHL()); },

            0xF1 => {
                const val = self.pop(mem);
                self.setAF(val);
            },
            0xC1 => { self.setBC(self.pop(mem)); },
            0xD1 => { self.setDE(self.pop(mem)); },
            0xE1 => { self.setHL(self.pop(mem)); },

            // ── 8-bit ALU ────────────────────────────────────────────
            // ADD A, r
            0x87 => { self.add(self.a); },
            0x80 => { self.add(self.b); },
            0x81 => { self.add(self.c); },
            0x82 => { self.add(self.d); },
            0x83 => { self.add(self.e); },
            0x84 => { self.add(self.h); },
            0x85 => { self.add(self.l); },
            0x86 => { self.add(mem.read(self.getHL())); },
            0xC6 => { self.add(self.readPc8(mem)); },

            // ADC A, r
            0x8F => { self.adc(self.a); },
            0x88 => { self.adc(self.b); },
            0x89 => { self.adc(self.c); },
            0x8A => { self.adc(self.d); },
            0x8B => { self.adc(self.e); },
            0x8C => { self.adc(self.h); },
            0x8D => { self.adc(self.l); },
            0x8E => { self.adc(mem.read(self.getHL())); },
            0xCE => { self.adc(self.readPc8(mem)); },

            // SUB A, r
            0x97 => { self.sub(self.a); },
            0x90 => { self.sub(self.b); },
            0x91 => { self.sub(self.c); },
            0x92 => { self.sub(self.d); },
            0x93 => { self.sub(self.e); },
            0x94 => { self.sub(self.h); },
            0x95 => { self.sub(self.l); },
            0x96 => { self.sub(mem.read(self.getHL())); },
            0xD6 => { self.sub(self.readPc8(mem)); },

            // SBC A, r
            0x9F => { self.sbc(self.a); },
            0x98 => { self.sbc(self.b); },
            0x99 => { self.sbc(self.c); },
            0x9A => { self.sbc(self.d); },
            0x9B => { self.sbc(self.e); },
            0x9C => { self.sbc(self.h); },
            0x9D => { self.sbc(self.l); },
            0x9E => { self.sbc(mem.read(self.getHL())); },
            0xDE => { self.sbc(self.readPc8(mem)); },

            // AND r
            0xA7 => { self.andOp(self.a); },
            0xA0 => { self.andOp(self.b); },
            0xA1 => { self.andOp(self.c); },
            0xA2 => { self.andOp(self.d); },
            0xA3 => { self.andOp(self.e); },
            0xA4 => { self.andOp(self.h); },
            0xA5 => { self.andOp(self.l); },
            0xA6 => { self.andOp(mem.read(self.getHL())); },
            0xE6 => { self.andOp(self.readPc8(mem)); },

            // OR r
            0xB7 => { self.orOp(self.a); },
            0xB0 => { self.orOp(self.b); },
            0xB1 => { self.orOp(self.c); },
            0xB2 => { self.orOp(self.d); },
            0xB3 => { self.orOp(self.e); },
            0xB4 => { self.orOp(self.h); },
            0xB5 => { self.orOp(self.l); },
            0xB6 => { self.orOp(mem.read(self.getHL())); },
            0xF6 => { self.orOp(self.readPc8(mem)); },

            // XOR r
            0xAF => { self.xor(self.a); },
            0xA8 => { self.xor(self.b); },
            0xA9 => { self.xor(self.c); },
            0xAA => { self.xor(self.d); },
            0xAB => { self.xor(self.e); },
            0xAC => { self.xor(self.h); },
            0xAD => { self.xor(self.l); },
            0xAE => { self.xor(mem.read(self.getHL())); },
            0xEE => { self.xor(self.readPc8(mem)); },

            // CP r
            0xBF => { self.cp(self.a); },
            0xB8 => { self.cp(self.b); },
            0xB9 => { self.cp(self.c); },
            0xBA => { self.cp(self.d); },
            0xBB => { self.cp(self.e); },
            0xBC => { self.cp(self.h); },
            0xBD => { self.cp(self.l); },
            0xBE => { self.cp(mem.read(self.getHL())); },
            0xFE => { self.cp(self.readPc8(mem)); },

            // INC r
            0x3C => { self.a = self.inc8(self.a); },
            0x04 => { self.b = self.inc8(self.b); },
            0x0C => { self.c = self.inc8(self.c); },
            0x14 => { self.d = self.inc8(self.d); },
            0x1C => { self.e = self.inc8(self.e); },
            0x24 => { self.h = self.inc8(self.h); },
            0x2C => { self.l = self.inc8(self.l); },

            // INC (HL)
            0x34 => {
                const hl = self.getHL();
                const val = mem.read(hl);
                mem.write(hl, self.inc8(val));
            },

            // DEC r
            0x3D => { self.a = self.dec8(self.a); },
            0x05 => { self.b = self.dec8(self.b); },
            0x0D => { self.c = self.dec8(self.c); },
            0x15 => { self.d = self.dec8(self.d); },
            0x1D => { self.e = self.dec8(self.e); },
            0x25 => { self.h = self.dec8(self.h); },
            0x2D => { self.l = self.dec8(self.l); },

            // DEC (HL)
            0x35 => {
                const hl = self.getHL();
                const val = mem.read(hl);
                mem.write(hl, self.dec8(val));
            },

            // ── 16-bit ALU ───────────────────────────────────────────
            0x09 => { self.add16(self.getBC()); },
            0x19 => { self.add16(self.getDE()); },
            0x29 => { self.add16(self.getHL()); },
            0x39 => { self.add16(self.sp); },

            // INC rr
            0x03 => { self.setBC(self.getBC() +% 1); },
            0x13 => { self.setDE(self.getDE() +% 1); },
            0x23 => { self.setHL(self.getHL() +% 1); },
            0x33 => { self.sp +%= 1; },

            // DEC rr
            0x0B => { self.setBC(self.getBC() -% 1); },
            0x1B => { self.setDE(self.getDE() -% 1); },
            0x2B => { self.setHL(self.getHL() -% 1); },
            0x3B => { self.sp -%= 1; },

            // ── General-purpose arithmetic / CPU control ─────────────
            0x27 => { self.daa(); }, // DAA
            0x2F => { // CPL
                self.a = ~self.a;
                self.setN(true);
                self.setH(true);
            },
            0x3F => { // CCF
                self.setN(false);
                self.setH(false);
                self.setC(self.getC() == 0);
            },
            0x37 => { // SCF
                self.setN(false);
                self.setH(false);
                self.setC(true);
            },
            0x00 => {}, // NOP
            0x76 => { self.halted = true; }, // HALT
            0x10 => { _ = self.readPc8(mem); }, // STOP (skip next byte)
            0xF3 => { self.ime = false; }, // DI
            0xFB => {
                // EI: enable IME after next instruction
                self.ime = true;
            },

            // ── Rotates and shifts ───────────────────────────────────
            0x07 => { // RLCA
                const bit7 = (self.a >> 7) & 1;
                self.a = ((self.a << 1) | bit7) & 0xFF;
                self.setZ(false);
                self.setN(false);
                self.setH(false);
                self.setC(bit7 == 1);
            },
            0x0F => { // RRCA
                const bit0 = self.a & 1;
                self.a = ((self.a >> 1) | (bit0 << 7)) & 0xFF;
                self.setZ(false);
                self.setN(false);
                self.setH(false);
                self.setC(bit0 == 1);
            },
            0x17 => { // RLA
                const bit7 = (self.a >> 7) & 1;
                const carry = self.getC();
                self.a = ((self.a << 1) | carry) & 0xFF;
                self.setZ(false);
                self.setN(false);
                self.setH(false);
                self.setC(bit7 == 1);
            },
            0x1F => { // RRA
                const bit0 = self.a & 1;
                const carry = self.getC();
                self.a = ((self.a >> 1) | (carry << 7)) & 0xFF;
                self.setZ(false);
                self.setN(false);
                self.setH(false);
                self.setC(bit0 == 1);
            },

            // ── Jumps ────────────────────────────────────────────────
            0xC3 => { // JP a16
                self.pc = self.readPc16(mem);
            },
            0xC2 => { // JP NZ, a16
                const addr = self.readPc16(mem);
                if (self.getZ() == 0) self.pc = addr;
            },
            0xCA => { // JP Z, a16
                const addr = self.readPc16(mem);
                if (self.getZ() == 1) self.pc = addr;
            },
            0xD2 => { // JP NC, a16
                const addr = self.readPc16(mem);
                if (self.getC() == 0) self.pc = addr;
            },
            0xDA => { // JP C, a16
                const addr = self.readPc16(mem);
                if (self.getC() == 1) self.pc = addr;
            },
            0xE9 => { // JP (HL)
                self.pc = self.getHL();
            },

            // JR e8
            0x18 => {
                const offset: i8 = @bitCast(self.readPc8(mem));
                self.pc +%= @as(u16, @bitCast(@as(i16, offset)));
            },
            0x20 => { // JR NZ, e8
                const offset: i8 = @bitCast(self.readPc8(mem));
                if (self.getZ() == 0) self.pc +%= @as(u16, @bitCast(@as(i16, offset)));
            },
            0x28 => { // JR Z, e8
                const offset: i8 = @bitCast(self.readPc8(mem));
                if (self.getZ() == 1) self.pc +%= @as(u16, @bitCast(@as(i16, offset)));
            },
            0x30 => { // JR NC, e8
                const offset: i8 = @bitCast(self.readPc8(mem));
                if (self.getC() == 0) self.pc +%= @as(u16, @bitCast(@as(i16, offset)));
            },
            0x38 => { // JR C, e8
                const offset: i8 = @bitCast(self.readPc8(mem));
                if (self.getC() == 1) self.pc +%= @as(u16, @bitCast(@as(i16, offset)));
            },

            // ── Calls ────────────────────────────────────────────────
            0xCD => { // CALL a16
                const addr = self.readPc16(mem);
                self.push(mem, self.pc);
                self.pc = addr;
            },
            0xC4 => { // CALL NZ, a16
                const addr = self.readPc16(mem);
                if (self.getZ() == 0) {
                    self.push(mem, self.pc);
                    self.pc = addr;
                }
            },
            0xCC => { // CALL Z, a16
                const addr = self.readPc16(mem);
                if (self.getZ() == 1) {
                    self.push(mem, self.pc);
                    self.pc = addr;
                }
            },
            0xD4 => { // CALL NC, a16
                const addr = self.readPc16(mem);
                if (self.getC() == 0) {
                    self.push(mem, self.pc);
                    self.pc = addr;
                }
            },
            0xDC => { // CALL C, a16
                const addr = self.readPc16(mem);
                if (self.getC() == 1) {
                    self.push(mem, self.pc);
                    self.pc = addr;
                }
            },

            // ── Restarts ─────────────────────────────────────────────
            0xC7 => { self.push(mem, self.pc); self.pc = 0x00; },
            0xCF => { self.push(mem, self.pc); self.pc = 0x08; },
            0xD7 => { self.push(mem, self.pc); self.pc = 0x10; },
            0xDF => { self.push(mem, self.pc); self.pc = 0x18; },
            0xE7 => { self.push(mem, self.pc); self.pc = 0x20; },
            0xEF => { self.push(mem, self.pc); self.pc = 0x28; },
            0xF7 => { self.push(mem, self.pc); self.pc = 0x30; },
            0xFF => { self.push(mem, self.pc); self.pc = 0x38; },

            // ── Returns ──────────────────────────────────────────────
            0xC9 => { self.pc = self.pop(mem); }, // RET
            0xC0 => { // RET NZ
                if (self.getZ() == 0) self.pc = self.pop(mem);
            },
            0xC8 => { // RET Z
                if (self.getZ() == 1) self.pc = self.pop(mem);
            },
            0xD0 => { // RET NC
                if (self.getC() == 0) self.pc = self.pop(mem);
            },
            0xD8 => { // RET C
                if (self.getC() == 1) self.pc = self.pop(mem);
            },
            0xD9 => { // RETI
                self.pc = self.pop(mem);
                self.ime = true;
            },

            // ── CB prefix ────────────────────────────────────────────
            0xCB => {
                const cb_op = self.readPc8(mem);
                cycles = self.execCB(mem, cb_op);
            },

            else => {
                // Unimplemented opcode
            },
        }

        return cycles;
    }

    // ── CB prefix opcodes ────────────────────────────────────────────
    fn execCB(self: *CPU, mem: *Memory, op: u8) u8 {
        var cycles: u8 = 8;
        const hl = self.getHL();

        switch (op) {
            // RLC r
            0x07 => { self.a = self.rlc(self.a); },
            0x00 => { self.b = self.rlc(self.b); },
            0x01 => { self.c = self.rlc(self.c); },
            0x02 => { self.d = self.rlc(self.d); },
            0x03 => { self.e = self.rlc(self.e); },
            0x04 => { self.h = self.rlc(self.h); },
            0x05 => { self.l = self.rlc(self.l); },
            0x06 => {
                const val = mem.read(hl);
                mem.write(hl, self.rlc(val));
                cycles = 16;
            },

            // RRC r
            0x0F => { self.a = self.rrc(self.a); },
            0x08 => { self.b = self.rrc(self.b); },
            0x09 => { self.c = self.rrc(self.c); },
            0x0A => { self.d = self.rrc(self.d); },
            0x0B => { self.e = self.rrc(self.e); },
            0x0C => { self.h = self.rrc(self.h); },
            0x0D => { self.l = self.rrc(self.l); },
            0x0E => {
                const val = mem.read(hl);
                mem.write(hl, self.rrc(val));
                cycles = 16;
            },

            // RL r
            0x17 => { self.a = self.rl(self.a); },
            0x10 => { self.b = self.rl(self.b); },
            0x11 => { self.c = self.rl(self.c); },
            0x12 => { self.d = self.rl(self.d); },
            0x13 => { self.e = self.rl(self.e); },
            0x14 => { self.h = self.rl(self.h); },
            0x15 => { self.l = self.rl(self.l); },
            0x16 => {
                const val = mem.read(hl);
                mem.write(hl, self.rl(val));
                cycles = 16;
            },

            // RR r
            0x1F => { self.a = self.rr(self.a); },
            0x18 => { self.b = self.rr(self.b); },
            0x19 => { self.c = self.rr(self.c); },
            0x1A => { self.d = self.rr(self.d); },
            0x1B => { self.e = self.rr(self.e); },
            0x1C => { self.h = self.rr(self.h); },
            0x1D => { self.l = self.rr(self.l); },
            0x1E => {
                const val = mem.read(hl);
                mem.write(hl, self.rr(val));
                cycles = 16;
            },

            // SLA r
            0x27 => { self.a = self.sla(self.a); },
            0x20 => { self.b = self.sla(self.b); },
            0x21 => { self.c = self.sla(self.c); },
            0x22 => { self.d = self.sla(self.d); },
            0x23 => { self.e = self.sla(self.e); },
            0x24 => { self.h = self.sla(self.h); },
            0x25 => { self.l = self.sla(self.l); },
            0x26 => {
                const val = mem.read(hl);
                mem.write(hl, self.sla(val));
                cycles = 16;
            },

            // SRA r
            0x2F => { self.a = self.sra(self.a); },
            0x28 => { self.b = self.sra(self.b); },
            0x29 => { self.c = self.sra(self.c); },
            0x2A => { self.d = self.sra(self.d); },
            0x2B => { self.e = self.sra(self.e); },
            0x2C => { self.h = self.sra(self.h); },
            0x2D => { self.l = self.sra(self.l); },
            0x2E => {
                const val = mem.read(hl);
                mem.write(hl, self.sra(val));
                cycles = 16;
            },

            // SRL r
            0x3F => { self.a = self.srl(self.a); },
            0x38 => { self.b = self.srl(self.b); },
            0x39 => { self.c = self.srl(self.c); },
            0x3A => { self.d = self.srl(self.d); },
            0x3B => { self.e = self.srl(self.e); },
            0x3C => { self.h = self.srl(self.h); },
            0x3D => { self.l = self.srl(self.l); },
            0x3E => {
                const val = mem.read(hl);
                mem.write(hl, self.srl(val));
                cycles = 16;
            },

            // SWAP r
            0x37 => { self.a = self.swap(self.a); },
            0x30 => { self.b = self.swap(self.b); },
            0x31 => { self.c = self.swap(self.c); },
            0x32 => { self.d = self.swap(self.d); },
            0x33 => { self.e = self.swap(self.e); },
            0x34 => { self.h = self.swap(self.h); },
            0x35 => { self.l = self.swap(self.l); },
            0x36 => {
                const val = mem.read(hl);
                mem.write(hl, self.swap(val));
                cycles = 16;
            },

            // BIT b, r and BIT b, (HL)
            0x40...0x7F => {
                const b = (op >> 3) & 0x07;
                const reg = op & 0x07;
                if (reg == 6) {
                    self.bit(@truncate(b), mem.read(hl));
                    cycles = 12;
                } else {
                    const val = switch (reg) {
                        0 => self.a,
                        1 => self.b,
                        2 => self.c,
                        3 => self.d,
                        4 => self.e,
                        5 => self.h,
                        7 => self.l,
                        else => unreachable,
                    };
                    self.bit(@truncate(b), val);
                }
            },

            // RES b, r
            0x80...0xBF => {
                const b = (op >> 3) & 0x07;
                const reg = op & 0x07;
                if (reg == 6) {
                    const val = mem.read(hl);
                    mem.write(hl, val & ~(@as(u8, 1) << @as(u3, @truncate(b))));
                    cycles = 16;
                } else {
                    const ptr = switch (reg) {
                        0 => &self.a,
                        1 => &self.b,
                        2 => &self.c,
                        3 => &self.d,
                        4 => &self.e,
                        5 => &self.h,
                        7 => &self.l,
                        else => unreachable,
                    };
                    ptr.* &= ~(@as(u8, 1) << @as(u3, @truncate(b)));
                }
            },

            // SET b, r
            0xC0...0xFF => {
                const b = (op >> 3) & 0x07;
                const reg = op & 0x07;
                if (reg == 6) {
                    const val = mem.read(hl);
                    mem.write(hl, val | (@as(u8, 1) << @as(u3, @truncate(b))));
                    cycles = 16;
                } else {
                    const ptr = switch (reg) {
                        0 => &self.a,
                        1 => &self.b,
                        2 => &self.c,
                        3 => &self.d,
                        4 => &self.e,
                        5 => &self.h,
                        7 => &self.l,
                        else => unreachable,
                    };
                    ptr.* |= (@as(u8, 1) << @as(u3, @truncate(b)));
                }
            },

        }

        return cycles;
    }

    // ── ALU helpers ──────────────────────────────────────────────────
    fn add(self: *CPU, val: u8) void {
        const result = @as(u16, self.a) + @as(u16, val);
        self.setH((self.a & 0x0F + val & 0x0F) > 0x0F);
        self.setC(result > 0xFF);
        self.a = @truncate(result);
        self.setZ(self.a == 0);
        self.setN(false);
    }

    fn adc(self: *CPU, val: u8) void {
        const carry = self.getC();
        const result = @as(u16, self.a) + @as(u16, val) + @as(u16, carry);
        self.setH((@as(u16, self.a & 0x0F) + @as(u16, val & 0x0F) + @as(u16, carry)) > 0x0F);
        self.setC(result > 0xFF);
        self.a = @truncate(result);
        self.setZ(self.a == 0);
        self.setN(false);
    }

    fn sub(self: *CPU, val: u8) void {
        const result: i16 = @as(i16, self.a) - @as(i16, val);
        self.setH((@as(i16, self.a & 0x0F) - @as(i16, val & 0x0F)) < 0);
        self.setC(result < 0);
        self.a = @as(u8, @bitCast(@as(i8, @truncate(result))));
        self.setZ(self.a == 0);
        self.setN(true);
    }

    fn sbc(self: *CPU, val: u8) void {
        const carry = self.getC();
        const result: i16 = @as(i16, self.a) - @as(i16, val) - @as(i16, carry);
        self.setH((@as(i16, self.a & 0x0F) - @as(i16, val & 0x0F) - @as(i16, carry)) < 0);
        self.setC(result < 0);
        self.a = @as(u8, @bitCast(@as(i8, @truncate(result))));
        self.setZ(self.a == 0);
        self.setN(true);
    }

    fn andOp(self: *CPU, val: u8) void {
        self.a &= val;
        self.setZ(self.a == 0);
        self.setN(false);
        self.setH(true);
        self.setC(false);
    }

    fn orOp(self: *CPU, val: u8) void {
        self.a |= val;
        self.setZ(self.a == 0);
        self.setN(false);
        self.setH(false);
        self.setC(false);
    }

    fn xor(self: *CPU, val: u8) void {
        self.a ^= val;
        self.setZ(self.a == 0);
        self.setN(false);
        self.setH(false);
        self.setC(false);
    }

    fn cp(self: *CPU, val: u8) void {
        const result: i16 = @as(i16, self.a) - @as(i16, val);
        self.setZ(result == 0);
        self.setN(true);
        self.setH((@as(i16, self.a & 0x0F) - @as(i16, val & 0x0F)) < 0);
        self.setC(result < 0);
    }

    fn inc8(self: *CPU, val: u8) u8 {
        const result = val +% 1;
        self.setZ(result == 0);
        self.setN(false);
        self.setH((val & 0x0F) == 0x0F);
        return result;
    }

    fn dec8(self: *CPU, val: u8) u8 {
        const result = val -% 1;
        self.setZ(result == 0);
        self.setN(true);
        self.setH((val & 0x0F) == 0);
        return result;
    }

    fn add16(self: *CPU, val: u16) void {
        const hl = self.getHL();
        const result = @as(u32, hl) + @as(u32, val);
        self.setN(false);
        self.setH((hl & 0x0FFF + val & 0x0FFF) > 0x0FFF);
        self.setC(result > 0xFFFF);
        self.setHL(@truncate(result));
    }

    fn daa(self: *CPU) void {
        var correction: u8 = 0;
        var adjust = false;

        if (self.getH() == 1 or (self.getN() == 0 and (self.a & 0x0F) > 9)) {
            correction |= 0x06;
        }
        if (self.getC() == 1 or (self.getN() == 0 and self.a > 0x99)) {
            correction |= 0x60;
            adjust = true;
        }

        if (self.getN() == 1) {
            self.a -%= correction;
        } else {
            self.a +%= correction;
        }

        if ((correction & 0x60) != 0) {
            self.setC(true);
        }
        self.setH(false);
        self.setZ(self.a == 0);
    }

    // CB rotate/shift helpers
    fn rlc(self: *CPU, val: u8) u8 {
        const bit7 = (val >> 7) & 1;
        const result = ((val << 1) | bit7) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit7 == 1);
        return result;
    }

    fn rrc(self: *CPU, val: u8) u8 {
        const bit0 = val & 1;
        const result = ((val >> 1) | (bit0 << 7)) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit0 == 1);
        return result;
    }

    fn rl(self: *CPU, val: u8) u8 {
        const bit7 = (val >> 7) & 1;
        const carry = self.getC();
        const result = ((val << 1) | carry) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit7 == 1);
        return result;
    }

    fn rr(self: *CPU, val: u8) u8 {
        const bit0 = val & 1;
        const carry = self.getC();
        const result = ((val >> 1) | (carry << 7)) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit0 == 1);
        return result;
    }

    fn sla(self: *CPU, val: u8) u8 {
        const bit7 = (val >> 7) & 1;
        const result = (val << 1) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit7 == 1);
        return result;
    }

    fn sra(self: *CPU, val: u8) u8 {
        const bit0 = val & 1;
        const bit7 = val & 0x80;
        const result = ((val >> 1) | bit7) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit0 == 1);
        return result;
    }

    fn srl(self: *CPU, val: u8) u8 {
        const bit0 = val & 1;
        const result = val >> 1;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(bit0 == 1);
        return result;
    }

    fn swap(self: *CPU, val: u8) u8 {
        const result = ((val >> 4) | (val << 4)) & 0xFF;
        self.setZ(result == 0);
        self.setN(false);
        self.setH(false);
        self.setC(false);
        return result;
    }

    fn bit(self: *CPU, b: u3, val: u8) void {
        const result = val & (@as(u8, 1) << @as(u3, @truncate(b)));
        self.setZ(result == 0);
        self.setN(false);
        self.setH(true);
    }
};
