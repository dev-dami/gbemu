const std = @import("std");

pub const Timer = struct {
    div: u16 = 0, // Internal counter (16-bit, only upper 8 bits visible at 0xFF04)
    tima: u8 = 0, // Timer counter (0xFF05)
    tma: u8 = 0, // Timer modulo (0xFF06)
    tac: u8 = 0, // Timer control (0xFF07)
    overflow_delay: u8 = 0, // Delay counter for overflow (4 cycles)

    pub fn init() Timer {
        return .{};
    }

    pub fn step(self: *Timer, cycles: u8, if_reg: *u8) void {
        // Handle overflow delay
        if (self.overflow_delay > 0) {
            self.overflow_delay -= 1;
            if (self.overflow_delay == 0) {
                // Reload TIMA with TMA
                self.tima = self.tma;
                // Set timer interrupt flag (bit 2 of IF register)
                if_reg.* |= 0x04;
            }
        }

        // Advance internal counter
        const old_div = self.div;
        self.div +%= @as(u16, cycles);

        // Check if timer is enabled (bit 2 of TAC)
        const timer_enabled = (self.tac & 0x04) != 0;

        if (timer_enabled) {
            // Get the clock select (bits 0-1 of TAC)
            const clock_select = self.tac & 0x03;

            // Determine the bit position in the internal counter to check
            const bit_pos: u4 = switch (clock_select) {
                0b00 => 9, // 4096 Hz: CPU cycles / 1024 = bit 9
                0b01 => 3, // 262144 Hz: CPU cycles / 16 = bit 3
                0b10 => 5, // 65536 Hz: CPU cycles / 64 = bit 5
                0b11 => 7, // 16384 Hz: CPU cycles / 256 = bit 7
                else => unreachable,
            };

            // Check if the selected bit transitioned from 1 to 0 (falling edge)
            const old_bit = (old_div >> bit_pos) & 1;
            const new_bit = (self.div >> bit_pos) & 1;

            if (old_bit == 1 and new_bit == 0) {
                // Increment TIMA
                if (self.tima == 0xFF) {
                    // Overflow: start delay counter
                    self.tima = 0;
                    self.overflow_delay = 4;
                } else {
                    self.tima +%= 1;
                }
            }
        }
    }

    pub fn read(self: *const Timer, addr: u16) u8 {
        return switch (addr) {
            0xFF04 => @truncate(self.div >> 8), // DIV: upper 8 bits of internal counter
            0xFF05 => self.tima, // TIMA
            0xFF06 => self.tma, // TMA
            0xFF07 => self.tac, // TAC
            else => 0xFF,
        };
    }

    pub fn write(self: *Timer, addr: u16, val: u8, if_reg: *u8) void {
        switch (addr) {
            0xFF04 => {
                // Writing to DIV resets the internal counter
                const old_div = self.div;
                self.div = 0;

                // Check if timer is enabled
                const timer_enabled = (self.tac & 0x04) != 0;
                if (timer_enabled) {
                    const clock_select = self.tac & 0x03;
                    const bit_pos: u4 = switch (clock_select) {
                        0b00 => 9,
                        0b01 => 3,
                        0b10 => 5,
                        0b11 => 7,
                        else => unreachable,
                    };

                    // Check if the selected bit was 1 before reset
                    const old_bit = (old_div >> bit_pos) & 1;
                    if (old_bit == 1) {
                        // Falling edge detected: increment TIMA
                        if (self.tima == 0xFF) {
                            self.tima = 0;
                            self.overflow_delay = 4;
                        } else {
                            self.tima +%= 1;
                        }
                    }
                }
            },
            0xFF05 => self.tima = val,
            0xFF06 => self.tma = val,
            0xFF07 => {
                // Writing to TAC can trigger TIMA increment if falling edge detected
                const old_tac = self.tac;
                self.tac = val;

                const old_enabled = (old_tac & 0x04) != 0;
                const new_enabled = (val & 0x04) != 0;
                const old_clock = old_tac & 0x03;
                const new_clock = val & 0x03;

                // If timer was enabled and either gets disabled or clock changes
                if (old_enabled) {
                    const old_bit_pos: u4 = switch (old_clock) {
                        0b00 => 9,
                        0b01 => 3,
                        0b10 => 5,
                        0b11 => 7,
                        else => unreachable,
                    };

                    const old_bit = (self.div >> old_bit_pos) & 1;

                    // Check if we're disabling or changing clock
                    if (!new_enabled or old_clock != new_clock) {
                        if (old_bit == 1) {
                            // Falling edge: increment TIMA
                            if (self.tima == 0xFF) {
                                self.tima = 0;
                                self.overflow_delay = 4;
                            } else {
                                self.tima +%= 1;
                            }
                        }
                    }
                }
            },
            else => {},
        }
        _ = if_reg; // Mark as used
    }
};
