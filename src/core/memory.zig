pub const Memory = struct {
    rom: [0x8000]u8 = .{0} ** 0x8000,
    vram: [0x2000]u8 = .{0} ** 0x2000,
    wram: [0x2000]u8 = .{0} ** 0x2000,
    hram: [0x80]u8 = .{0} ** 0x80,
    io: [0x80]u8 = .{0} ** 0x80,
    oam: [0xA0]u8 = .{0} ** 0xA0,

    pub fn init() Memory {
        return .{};
    }

    pub fn read(self: *const Memory, addr: u16) u8 {
        if (addr < 0x8000) return self.rom[addr];
        if (addr >= 0x8000 and addr < 0xA000) return self.vram[addr - 0x8000];
        if (addr >= 0xC000 and addr < 0xE000) return self.wram[addr - 0xC000];
        if (addr >= 0xE000 and addr < 0xFE00) return self.wram[addr - 0xE000]; // echo RAM
        if (addr >= 0xFE00 and addr < 0xFEA0) return self.oam[addr - 0xFE00];
        if (addr >= 0xFF00 and addr < 0xFF80) return self.io[addr - 0xFF00];
        if (addr >= 0xFF80) return self.hram[addr - 0xFF80];
        return 0xFF;
    }

    pub fn write(self: *Memory, addr: u16, val: u8) void {
        if (addr < 0x8000) return; // ROM is read-only
        if (addr >= 0x8000 and addr < 0xA000) {
            self.vram[addr - 0x8000] = val;
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
            self.io[addr - 0xFF00] = val;
            return;
        }
        if (addr >= 0xFF80) {
            self.hram[addr - 0xFF80] = val;
            return;
        }
    }
};
