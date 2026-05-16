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
    }

    pub fn unload(self: *Cartridge) void {
        if (self.rom_data) |data| {
            self.allocator.free(data);
            self.rom_data = null;
        }
    }
};
