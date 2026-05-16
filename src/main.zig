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

        // Map SDL keys to Game Boy buttons
        const is_keydown = event.type == c.SDL_KEYDOWN;
        const is_keyup = event.type == c.SDL_KEYUP;

        if (is_keydown or is_keyup) {
            const pressed = is_keydown;
            const sym = event.key.keysym.sym;

            // D-Pad
            if (sym == c.SDLK_UP) {
                gb.input.setButton(.up, pressed);
            } else if (sym == c.SDLK_DOWN) {
                gb.input.setButton(.down, pressed);
            } else if (sym == c.SDLK_LEFT) {
                gb.input.setButton(.left, pressed);
            } else if (sym == c.SDLK_RIGHT) {
                gb.input.setButton(.right, pressed);
            }
            // Buttons
            else if (sym == c.SDLK_z) {
                gb.input.setButton(.a, pressed);
            } else if (sym == c.SDLK_x) {
                gb.input.setButton(.b, pressed);
            } else if (sym == c.SDLK_RETURN) {
                gb.input.setButton(.start, pressed);
            } else if (sym == c.SDLK_SPACE) {
                gb.input.setButton(.select, pressed);
            }
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
        std.debug.print("Usage: gameboy <rom.gb> [--debug] [--steps N]\n", .{});
        return;
    }

    var rom_path: []const u8 = "";
    var debug_mode = false;
    var headless_steps: u32 = 0;

    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const arg = std.mem.sliceTo(argv[i], 0);
        if (std.mem.eql(u8, arg, "--debug")) {
            debug_mode = true;
        } else if (std.mem.eql(u8, arg, "--steps")) {
            i += 1;
            if (i < argv.len) {
                const steps_arg = std.mem.sliceTo(argv[i], 0);
                headless_steps = std.fmt.parseInt(u32, steps_arg, 10) catch 0;
            }
        } else if (rom_path.len == 0) {
            rom_path = arg;
        }
    }

    if (rom_path.len == 0) {
        std.debug.print("Usage: gameboy <rom.gb> [--debug] [--steps N]\n", .{});
        return;
    }

    if (headless_steps > 0) {
        // Headless test mode: run N steps and dump state
        var gb = GameBoy.init(init.gpa);
        gb.debug = debug_mode;

        gb.loadRom(init.io, rom_path) catch |err| {
            std.debug.print("Failed to load ROM: {s} ({})\n", .{ rom_path, err });
            return;
        };
        defer gb.unloadRom();

        std.debug.print("ROM loaded. Running {d} steps in headless mode...\n", .{headless_steps});

        var step_count: u32 = 0;
        while (step_count < headless_steps) : ({
            step_count += 1;
        }) {
            gb.step();
        }

        std.debug.print("\n--- CPU State after {d} steps ---\n", .{step_count});
        std.debug.print("  PC: 0x{X:0>4}  SP: 0x{X:0>4}\n", .{ gb.cpu.pc, gb.cpu.sp });
        std.debug.print("  A: 0x{X:0>2}  F: 0x{X:0>2}  B: 0x{X:0>2}  C: 0x{X:0>2}\n", .{ gb.cpu.a, gb.cpu.f, gb.cpu.b, gb.cpu.c });
        std.debug.print("  D: 0x{X:0>2}  E: 0x{X:0>2}  H: 0x{X:0>2}  L: 0x{X:0>2}\n", .{ gb.cpu.d, gb.cpu.e, gb.cpu.h, gb.cpu.l });
        std.debug.print("  Z:{d} N:{d} H:{d} C:{d}\n", .{ gb.cpu.getZ(), gb.cpu.getN(), gb.cpu.getH(), gb.cpu.getC() });
        std.debug.print("  HALTED: {}\n", .{gb.cpu.halted});
        return;
    }

    // GUI mode
    if (!platformInit()) return;
    defer platformDeinit();

    var gb = GameBoy.init(init.gpa);
    gb.debug = debug_mode;

    gb.loadRom(init.io, rom_path) catch |err| {
        std.debug.print("Failed to load ROM: {s} ({})\n", .{ rom_path, err });
        return;
    };
    defer gb.unloadRom();

    std.debug.print("ROM loaded, starting emulation...\n", .{});
    std.debug.print("Initial PC: 0x{X:0>4}\n", .{gb.cpu.pc});

    while (gb.running) {
        gb.step();
        platformPollEvents(&gb);
        platformRender(&gb.framebuffer);
    }
}
