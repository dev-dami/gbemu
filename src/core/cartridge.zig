const std = @import("std");

pub const Cartridge = struct {
    rom_data: ?[]u8 = null,
    allocator: std.mem.Allocator,

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
