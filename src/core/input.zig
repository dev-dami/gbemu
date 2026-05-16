const std = @import("std");

pub const Button = enum {
    up,
    down,
    left,
    right,
    a,
    b,
    start,
    select,
};

pub const Input = struct {
    // Button states (true = pressed, false = not pressed)
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    a: bool = false,
    b: bool = false,
    start: bool = false,
    select: bool = false,

    // JOY register (0xFF00) selection bits
    // Bit 4: 0 = read D-Pad, 1 = read Buttons
    // Bit 5: 0 = read Buttons, 1 = read D-Pad
    joy_select: u8 = 0xFF,

    pub fn init() Input {
        return .{};
    }

    /// Read JOY register (0xFF00)
    /// Returns button states based on selection bits
    pub fn read(self: *const Input, addr: u16) u8 {
        if (addr != 0xFF00) return 0xFF;

        var result = self.joy_select & 0xF0; // Keep selection bits

        // Bit 4 = 0: Read D-Pad (bits 0-3: Right, Left, Up, Down)
        if ((self.joy_select & 0x10) == 0) {
            if (!self.right) result &= ~@as(u8, 0x01);
            if (!self.left) result &= ~@as(u8, 0x02);
            if (!self.up) result &= ~@as(u8, 0x04);
            if (!self.down) result &= ~@as(u8, 0x08);
        }

        // Bit 5 = 0: Read Buttons (bits 0-3: A, B, Select, Start)
        if ((self.joy_select & 0x20) == 0) {
            if (!self.a) result &= ~@as(u8, 0x01);
            if (!self.b) result &= ~@as(u8, 0x02);
            if (!self.select) result &= ~@as(u8, 0x04);
            if (!self.start) result &= ~@as(u8, 0x08);
        }

        return result;
    }

    /// Write JOY register (0xFF00)
    /// Updates selection bits
    pub fn write(self: *Input, addr: u16, val: u8) void {
        if (addr != 0xFF00) return;
        self.joy_select = val | 0x0F; // Keep lower 4 bits as 1 (not pressed)
    }

    /// Set button state
    pub fn setButton(self: *Input, button: Button, pressed: bool) void {
        switch (button) {
            .up => self.up = pressed,
            .down => self.down = pressed,
            .left => self.left = pressed,
            .right => self.right = pressed,
            .a => self.a = pressed,
            .b => self.b = pressed,
            .start => self.start = pressed,
            .select => self.select = pressed,
        }
    }

    /// Check if any button was newly pressed and trigger interrupt if needed
    pub fn step(self: *Input, if_reg: *u8) void {
        // Check if any button is pressed
        const any_pressed = self.up or self.down or self.left or self.right or
            self.a or self.b or self.start or self.select;

        // Set bit 4 of IF register if any button is pressed
        if (any_pressed) {
            if_reg.* |= 0x10;
        }
    }
};
