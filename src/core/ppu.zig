const Memory = @import("memory.zig").Memory;

// LCD Control (LCDC) bit flags
pub const LCDC_BG_ENABLE: u8 = 1 << 0;
pub const LCDC_OBJ_ENABLE: u8 = 1 << 1;
pub const LCDC_OBJ_SIZE: u8 = 1 << 2;
pub const LCDC_BG_MAP: u8 = 1 << 3;
pub const LCDC_ADDR_MODE: u8 = 1 << 4;
pub const LCDC_WIN_ENABLE: u8 = 1 << 5;
pub const LCDC_WIN_MAP: u8 = 1 << 6;
pub const LCDC_LCD_ENABLE: u8 = 1 << 7;

// PPU mode constants
pub const PPU_MODE_HBLANK: u8 = 0;
pub const PPU_MODE_VBLANK: u8 = 1;
pub const PPU_MODE_OAM: u8 = 2;
pub const PPU_MODE_TRANSFER: u8 = 3;

// Dot timing per scanline
pub const PPU_DOTS_MODE2: u16 = 80;
pub const PPU_DOTS_MODE3: u16 = 172;
pub const PPU_DOTS_LINE: u16 = 456;
pub const PPU_SCANLINES: u8 = 154;
pub const PPU_HEIGHT: u8 = 144;
pub const PPU_WIDTH: u8 = 160;

const GB_COLORS: [4][3]u8 = .{
    .{ 255, 255, 255 },
    .{ 170, 170, 170 },
    .{ 85, 85, 85 },
    .{ 0, 0, 0 },
};

pub const PPU = struct {
    lcdc: u8 = 0x91,
    stat: u8 = 0x81,
    scy: u8 = 0,
    scx: u8 = 0,
    ly: u8 = 0,
    lyc: u8 = 0,
    dma: u8 = 0,
    bgp: [4]u8 = .{ 0, 0, 0, 0 },
    obp: [2][4]u8 = .{ .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } },
    wx: u8 = 0,
    wy: u8 = 0,

    // Internal state
    mode: u8 = PPU_MODE_OAM,
    dots: u16 = 0,
    frame_ready: bool = false,

    pub fn init() PPU {
        return .{};
    }

    fn renderScanline(self: *PPU, mem: *const Memory, fb: []u8) void {
        if (self.lcdc & LCDC_BG_ENABLE == 0) return;

        const ly = self.ly;
        if (ly >= PPU_HEIGHT) return;

        const bg_map: u16 = if (self.lcdc & LCDC_BG_MAP != 0) 0x1C00 else 0x1800;
        const ly_u16: u16 = @intCast(ly);

        for (0..PPU_WIDTH) |x_usize| {
            const x: u16 = @intCast(x_usize);
            const col: u16 = (x +% @as(u16, self.scx)) % 256;
            const row: u16 = (ly_u16 +% @as(u16, self.scy)) % 256;

            const tile_x = col / 8;
            const tile_y = row / 8;
            const map_addr = bg_map + tile_y * 32 + tile_x;
            const tile_num = mem.read(@as(u16, 0x8000) +% @as(u16, @truncate(map_addr)));

            const tile_offset: u16 = if (self.lcdc & LCDC_ADDR_MODE != 0)
                @as(u16, tile_num) * 16
            else blk: {
                const signed_num: i16 = @as(i16, @as(i8, @bitCast(tile_num)));
                break :blk @as(u16, @bitCast(@as(i16, 0x800) +% signed_num * 16));
            };

            const row_in_tile = row % 8;
            const tile_row_addr = tile_offset +% @as(u16, @truncate(row_in_tile * 2));
            const b1 = mem.read(0x8000 +% tile_row_addr);
            const b2 = mem.read(0x8000 +% tile_row_addr +% 1);

            const px_in_tile: u3 = @intCast(7 - (col % 8));
            const color_idx: u2 = @truncate((@as(u8, (b2 >> px_in_tile)) & 1) << 1 | ((@as(u8, b1 >> px_in_tile)) & 1));
            const shade = self.bgp[color_idx];

            const c = GB_COLORS[shade % 4];
            const offset = (@as(usize, ly) * PPU_WIDTH + x_usize) * 4;
            fb[offset + 0] = c[0];
            fb[offset + 1] = c[1];
            fb[offset + 2] = c[2];
            fb[offset + 3] = 255;
        }
    }

    pub fn step(self: *PPU, mem: *const Memory, framebuffer: []u8) void {
        if (self.lcdc & LCDC_LCD_ENABLE == 0) {
            self.mode = PPU_MODE_HBLANK;
            self.ly = 0;
            self.dots = 0;
            return;
        }

        self.dots += 1;

        if (self.ly < PPU_HEIGHT) {
            if (self.mode == PPU_MODE_OAM and self.dots >= PPU_DOTS_MODE2) {
                self.mode = PPU_MODE_TRANSFER;
            } else if (self.mode == PPU_MODE_TRANSFER and self.dots >= PPU_DOTS_MODE2 + PPU_DOTS_MODE3) {
                self.mode = PPU_MODE_HBLANK;
                self.renderScanline(mem, framebuffer);
            } else if (self.mode == PPU_MODE_HBLANK and self.dots >= PPU_DOTS_LINE) {
                self.ly += 1;
                self.dots = 0;
                self.mode = PPU_MODE_OAM;
                if (self.ly >= PPU_HEIGHT) {
                    self.mode = PPU_MODE_VBLANK;
                }
            }
        } else if (self.ly < PPU_SCANLINES) {
            self.mode = PPU_MODE_VBLANK;
            if (self.dots >= PPU_DOTS_LINE) {
                self.ly += 1;
                self.dots = 0;
                if (self.ly >= PPU_SCANLINES) {
                    self.frame_ready = true;
                    self.ly = 0;
                    self.mode = PPU_MODE_OAM;
                }
            }
        } else {
            self.ly = 0;
            self.dots = 0;
            self.mode = PPU_MODE_OAM;
        }

        self.stat = (self.stat & 0xFC) | self.mode;
        if (self.ly == self.lyc) self.stat |= 0x04;
    }
};
