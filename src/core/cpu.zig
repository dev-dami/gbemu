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

    fn readPc8(self: *CPU, mem: *const Memory) u8 {
        const val = mem.read(self.pc);
        self.pc +%= 1;
        return val;
    }

    pub fn step(self: *CPU, mem: *Memory) void {
        const opcode = self.readPc8(mem);

        switch (opcode) {
            0x00 => {
                // NOP
            },
            0x01 => {
                // LD BC, d16
                self.c = self.readPc8(mem);
                self.b = self.readPc8(mem);
            },
            0x02 => {
                // LD (BC), A
                const addr = (@as(u16, self.b) << 8) | @as(u16, self.c);
                mem.write(addr, self.a);
            },
            0xC3 => {
                // JP a16
                const lo = self.readPc8(mem);
                const hi = self.readPc8(mem);
                self.pc = (@as(u16, hi) << 8) | @as(u16, lo);
            },
            0xAF => {
                // XOR A
                self.a = 0;
                self.f = 0x80;
            },
            0x3E => {
                // LD A, d8
                self.a = self.readPc8(mem);
            },
            0x0E => {
                // LD C, d8
                self.c = self.readPc8(mem);
            },
            0x06 => {
                // LD B, d8
                self.b = self.readPc8(mem);
            },
            else => {
                // Unimplemented opcode
            },
        }
    }
};
