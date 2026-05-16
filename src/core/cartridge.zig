const std = @import("std");

pub const CartridgeType = enum(u8) {
    ROM_ONLY = 0x00,
    MBC1 = 0x01,
    MBC1_RAM = 0x02,
    MBC1_RAM_BATTERY = 0x03,
    MBC5 = 0x19,
    MBC5_RAM = 0x1A,
    MBC5_RAM_BATTERY = 0x1B,
    MBC5_RUMBLE = 0x1C,
    MBC5_RUMBLE_RAM = 0x1D,
    MBC5_RUMBLE_RAM_BATTERY = 0x1E,
    _,
};

pub const Cartridge = struct {
    rom_data: ?[]u8 = null,
    ram_data: ?[]u8 = null,
    allocator: std.mem.Allocator,

    // Cartridge metadata
    cart_type: CartridgeType = .ROM_ONLY,
    rom_size_kb: u32 = 0,
    ram_size_kb: u32 = 0,

    // MBC state
    ram_enabled: bool = false,
    rom_bank: u16 = 1,
    ram_bank: u8 = 0,
    banking_mode: u8 = 0, // 0=ROM, 1=RAM (MBC1 only)

    pub fn init(allocator: std.mem.Allocator) Cartridge {
        return .{ .allocator = allocator };
    }

    pub fn load(self: *Cartridge, io: std.Io, path: []const u8) !void {
        const dir = std.Io.Dir.cwd();
        var file = try dir.openFile(io, path, .{});
        defer file.close(io);

        const stat = try file.stat(io);
        const rom_data = try self.allocator.alloc(u8, @intCast(stat.size));

        const bytes_read = try file.readPositionalAll(io, rom_data, 0);
        if (bytes_read != stat.size) {
            self.allocator.free(rom_data);
            return error.IncompleteRead;
        }

        self.rom_data = rom_data;

        // Parse cartridge header
        if (rom_data.len >= 0x150) {
            self.cart_type = @enumFromInt(rom_data[0x0147]);
            self.parseRomSize(rom_data[0x0148]);
            self.parseRamSize(rom_data[0x0149]);

            // Allocate external RAM based on size
            if (self.ram_size_kb > 0) {
                const ram_bytes = self.ram_size_kb * 1024;
                self.ram_data = try self.allocator.alloc(u8, ram_bytes);
                @memset(self.ram_data.?, 0);
            }
        }
    }

    fn parseRomSize(self: *Cartridge, size_byte: u8) void {
        self.rom_size_kb = switch (size_byte) {
            0x00 => 32,
            0x01 => 64,
            0x02 => 128,
            0x03 => 256,
            0x04 => 512,
            0x05 => 1024,
            0x06 => 2048,
            0x07 => 4096,
            0x08 => 8192,
            else => 32,
        };
    }

    fn parseRamSize(self: *Cartridge, size_byte: u8) void {
        self.ram_size_kb = switch (size_byte) {
            0x00 => 0,
            0x01 => 2,
            0x02 => 8,
            0x03 => 32,
            0x04 => 128,
            0x05 => 64,
            else => 0,
        };
    }

    pub fn unload(self: *Cartridge) void {
        if (self.rom_data) |data| {
            self.allocator.free(data);
            self.rom_data = null;
        }
        if (self.ram_data) |data| {
            self.allocator.free(data);
            self.ram_data = null;
        }
    }

    pub fn readRom(self: *const Cartridge, addr: u16) u8 {
        const rom_data = self.rom_data orelse return 0xFF;

        return switch (self.cart_type) {
            .ROM_ONLY => {
                if (addr < rom_data.len) return rom_data[addr] else return 0xFF;
            },
            .MBC1, .MBC1_RAM, .MBC1_RAM_BATTERY => self.readRomMBC1(rom_data, addr),
            .MBC5, .MBC5_RAM, .MBC5_RAM_BATTERY, .MBC5_RUMBLE, .MBC5_RUMBLE_RAM, .MBC5_RUMBLE_RAM_BATTERY => self.readRomMBC5(rom_data, addr),
            else => if (addr < rom_data.len) rom_data[addr] else 0xFF,
        };
    }

    fn readRomMBC1(self: *const Cartridge, rom_data: []u8, addr: u16) u8 {
        const rom_data_len = rom_data.len;

        if (addr < 0x4000) {
            // Bank 0 is always mapped to 0x0000-0x3FFF
            if (addr < rom_data_len) return rom_data[addr] else return 0xFF;
        } else if (addr < 0x8000) {
            // Switchable bank mapped to 0x4000-0x7FFF
            var bank = self.rom_bank & 0x1F; // bits 0-4
            if (self.banking_mode == 0) {
                // ROM mode: use upper bits from ram_bank
                bank |= (@as(u16, self.ram_bank & 0x03) << 5);
            }
            if (bank == 0) bank = 1; // Bank 0 is invalid in switchable area

            const offset = (@as(usize, bank) * 0x4000) + (addr - 0x4000);
            if (offset < rom_data_len) return rom_data[offset] else return 0xFF;
        }
        return 0xFF;
    }

    fn readRomMBC5(self: *const Cartridge, rom_data: []u8, addr: u16) u8 {
        const rom_data_len = rom_data.len;

        if (addr < 0x4000) {
            // Bank 0 is always mapped to 0x0000-0x3FFF
            if (addr < rom_data_len) return rom_data[addr] else return 0xFF;
        } else if (addr < 0x8000) {
            // Switchable bank mapped to 0x4000-0x7FFF
            const bank = self.rom_bank & 0x1FF; // 9-bit bank number
            const offset = (@as(usize, bank) * 0x4000) + (addr - 0x4000);
            if (offset < rom_data_len) return rom_data[offset] else return 0xFF;
        }
        return 0xFF;
    }

    pub fn readRam(self: *const Cartridge, addr: u16) u8 {
        if (!self.ram_enabled) return 0xFF;
        if (self.ram_data == null) return 0xFF;

        const ram_data = self.ram_data.?;
        const ram_size = ram_data.len;

        return switch (self.cart_type) {
            .MBC1_RAM, .MBC1_RAM_BATTERY => {
                if (addr >= 0xA000 and addr < 0xC000) {
                    const offset = (@as(usize, self.ram_bank & 0x03) * 0x2000) + (addr - 0xA000);
                    if (offset < ram_size) return ram_data[offset] else return 0xFF;
                }
                return 0xFF;
            },
            .MBC5_RAM, .MBC5_RAM_BATTERY, .MBC5_RUMBLE_RAM, .MBC5_RUMBLE_RAM_BATTERY => {
                if (addr >= 0xA000 and addr < 0xC000) {
                    const offset = (@as(usize, self.ram_bank & 0x0F) * 0x2000) + (addr - 0xA000);
                    if (offset < ram_size) return ram_data[offset] else return 0xFF;
                }
                return 0xFF;
            },
            else => 0xFF,
        };
    }

    pub fn writeRom(self: *Cartridge, addr: u16, val: u8) void {
        switch (self.cart_type) {
            .ROM_ONLY => {},
            .MBC1, .MBC1_RAM, .MBC1_RAM_BATTERY => self.writeRomMBC1(addr, val),
            .MBC5, .MBC5_RAM, .MBC5_RAM_BATTERY, .MBC5_RUMBLE, .MBC5_RUMBLE_RAM, .MBC5_RUMBLE_RAM_BATTERY => self.writeRomMBC5(addr, val),
            else => {},
        }
    }

    fn writeRomMBC1(self: *Cartridge, addr: u16, val: u8) void {
        if (addr < 0x2000) {
            // RAM enable register
            self.ram_enabled = (val & 0x0F) == 0x0A;
        } else if (addr < 0x4000) {
            // ROM bank number (bits 0-4)
            self.rom_bank = (self.rom_bank & 0xE0) | (@as(u16, val & 0x1F));
            if ((self.rom_bank & 0x1F) == 0) {
                self.rom_bank = (self.rom_bank & 0xE0) | 1;
            }
        } else if (addr < 0x6000) {
            // RAM bank or upper ROM bank bits
            self.ram_bank = val & 0x03;
        } else if (addr < 0x8000) {
            // Banking mode select
            self.banking_mode = val & 0x01;
        }
    }

    fn writeRomMBC5(self: *Cartridge, addr: u16, val: u8) void {
        if (addr < 0x2000) {
            // RAM enable register
            self.ram_enabled = (val & 0x0F) == 0x0A;
        } else if (addr < 0x3000) {
            // ROM bank low (bits 0-7)
            self.rom_bank = (self.rom_bank & 0x100) | @as(u16, val);
        } else if (addr < 0x4000) {
            // ROM bank high (bit 8)
            self.rom_bank = (self.rom_bank & 0x0FF) | (@as(u16, val & 0x01) << 8);
        } else if (addr < 0x6000) {
            // RAM bank (bits 0-3)
            self.ram_bank = val & 0x0F;
        }
    }

    pub fn writeRam(self: *Cartridge, addr: u16, val: u8) void {
        if (!self.ram_enabled) return;
        if (self.ram_data == null) return;

        const ram_data = self.ram_data.?;
        const ram_size = ram_data.len;

        if (addr >= 0xA000 and addr < 0xC000) {
            var offset: usize = 0;
            switch (self.cart_type) {
                .MBC1_RAM, .MBC1_RAM_BATTERY => {
                    offset = (@as(usize, self.ram_bank & 0x03) * 0x2000) + (addr - 0xA000);
                },
                .MBC5_RAM, .MBC5_RAM_BATTERY, .MBC5_RUMBLE_RAM, .MBC5_RUMBLE_RAM_BATTERY => {
                    offset = (@as(usize, self.ram_bank & 0x0F) * 0x2000) + (addr - 0xA000);
                },
                else => return,
            }

            if (offset < ram_size) {
                ram_data[offset] = val;
            }
        }
    }
};
