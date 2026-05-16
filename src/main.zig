const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const GameBoy = @import("core/gb.zig").GameBoy;

var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var texture: ?*c.SDL_Texture = null;

fn platformInit() bool {
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
        std.debug.print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return false;
    }

    window = c.SDL_CreateWindow(
        "GameBoy",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        480,
        432,
        c.SDL_WINDOW_SHOWN,
    );
    if (window == null) {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
        c.SDL_Quit();
        return false;
    }

    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC);
    if (renderer == null) {
        std.debug.print("SDL_CreateRenderer failed: {s}\n", .{c.SDL_GetError()});
        c.SDL_DestroyWindow(window);
        c.SDL_Quit();
        return false;
    }

    texture = c.SDL_CreateTexture(
        renderer,
        c.SDL_PIXELFORMAT_RGBA32,
        c.SDL_TEXTUREACCESS_STREAMING,
        160,
        144,
    );
    if (texture == null) {
        std.debug.print("SDL_CreateTexture failed: {s}\n", .{c.SDL_GetError()});
        c.SDL_DestroyRenderer(renderer);
        c.SDL_DestroyWindow(window);
        c.SDL_Quit();
        return false;
    }

    return true;
}

fn platformPollEvents(gb: *GameBoy) void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        if (event.type == c.SDL_QUIT) {
            gb.running = false;
        }
        if (event.type == c.SDL_KEYDOWN and event.key.keysym.sym == c.SDLK_ESCAPE) {
            gb.running = false;
        }
    }
}

fn platformRender(framebuffer: []const u8) void {
    const ren = renderer orelse return;
    const tex = texture orelse return;

    _ = c.SDL_UpdateTexture(tex, null, framebuffer.ptr, 160 * 4);
    _ = c.SDL_RenderClear(ren);
    _ = c.SDL_RenderCopy(ren, tex, null, null);
    c.SDL_RenderPresent(ren);
}

fn platformDeinit() void {
    if (texture) |tex| c.SDL_DestroyTexture(tex);
    if (renderer) |ren| c.SDL_DestroyRenderer(ren);
    if (window) |win| c.SDL_DestroyWindow(win);
    c.SDL_Quit();
}

pub fn main(init: std.process.Init) !void {
    const argv = init.minimal.args.vector;
    if (argv.len < 2) {
        std.debug.print("Usage: gameboy <rom.gb>\n", .{});
        return;
    }

    const rom_path = std.mem.sliceTo(argv[1], 0);

    if (!platformInit()) return;
    defer platformDeinit();

    var gb = GameBoy.init();

    gb.loadRom(init.io, init.gpa, rom_path) catch |err| {
        std.debug.print("Failed to load ROM: {s} ({})\n", .{ rom_path, err });
        return;
    };

    std.debug.print("ROM loaded, starting emulation...\n", .{});
    std.debug.print("Initial PC: 0x{X:0>4}\n", .{gb.cpu.pc});

    while (gb.running) {
        gb.step();
        platformPollEvents(&gb);
        platformRender(&gb.framebuffer);
    }
}
