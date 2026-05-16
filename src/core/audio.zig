const std = @import("std");

pub const Audio = struct {
    // Channel 1: Square wave with sweep
    ch1_sweep: u8 = 0, // 0xFF10
    ch1_duty_len: u8 = 0, // 0xFF11
    ch1_env: u8 = 0, // 0xFF12
    ch1_freq_low: u8 = 0, // 0xFF13
    ch1_freq_high: u8 = 0, // 0xFF14
    ch1_enabled: bool = false,
    ch1_freq_timer: u16 = 0,
    ch1_phase: u8 = 0,

    // Channel 2: Square wave (no sweep)
    ch2_duty_len: u8 = 0, // 0xFF16
    ch2_env: u8 = 0, // 0xFF17
    ch2_freq_low: u8 = 0, // 0xFF18
    ch2_freq_high: u8 = 0, // 0xFF19
    ch2_enabled: bool = false,
    ch2_freq_timer: u16 = 0,
    ch2_phase: u8 = 0,

    // Channel 3: Wave output (custom waveform)
    ch3_enable: u8 = 0, // 0xFF1A
    ch3_len: u8 = 0, // 0xFF1B
    ch3_volume: u8 = 0, // 0xFF1C
    ch3_freq_low: u8 = 0, // 0xFF1D
    ch3_freq_high: u8 = 0, // 0xFF1E
    ch3_enabled: bool = false,
    ch3_freq_timer: u16 = 0,
    ch3_wave_index: u8 = 0,
    wave_ram: [16]u8 = .{0} ** 16, // 0xFF30-0xFF3F

    // Channel 4: Noise generator
    ch4_len_env: u8 = 0, // 0xFF20
    ch4_poly: u8 = 0, // 0xFF21
    ch4_freq_ctrl: u8 = 0, // 0xFF22
    ch4_enabled: bool = false,
    ch4_freq_timer: u16 = 0,
    ch4_lfsr: u16 = 0x7FFF,

    // Master control
    master_volume: u8 = 0, // 0xFF24 (VIN to SO)
    sound_select: u8 = 0, // 0xFF25 (L/R channel select)
    sound_on: u8 = 0, // 0xFF26 (Sound on/off)

    pub fn init() Audio {
        return .{};
    }

    pub fn step(self: *Audio, cycles: u8) void {
        const cycle_count = @as(u16, cycles);

        // Step channel 1
        if (self.ch1_enabled) {
            self.ch1_freq_timer +%= cycle_count;
            const freq = self.getFrequency(self.ch1_freq_low, self.ch1_freq_high);
            const period = (2048 - freq) * 4;
            if (self.ch1_freq_timer >= period) {
                self.ch1_freq_timer = 0;
                self.ch1_phase = (self.ch1_phase + 1) % 8;
            }
        }

        // Step channel 2
        if (self.ch2_enabled) {
            self.ch2_freq_timer +%= cycle_count;
            const freq = self.getFrequency(self.ch2_freq_low, self.ch2_freq_high);
            const period = (2048 - freq) * 4;
            if (self.ch2_freq_timer >= period) {
                self.ch2_freq_timer = 0;
                self.ch2_phase = (self.ch2_phase + 1) % 8;
            }
        }

        // Step channel 3
        if (self.ch3_enabled) {
            self.ch3_freq_timer +%= cycle_count;
            const freq = self.getFrequency(self.ch3_freq_low, self.ch3_freq_high);
            const period = (2048 - freq) * 2;
            if (self.ch3_freq_timer >= period) {
                self.ch3_freq_timer = 0;
                self.ch3_wave_index = (self.ch3_wave_index + 1) % 32;
            }
        }

        // Step channel 4
        if (self.ch4_enabled) {
            self.ch4_freq_timer +%= cycle_count;
            const shift = (self.ch4_poly >> 4) & 0x0F;
            const period = @as(u16, self.ch4_poly & 0x0F) << @as(u4, @truncate(shift + 3));
            if (self.ch4_freq_timer >= period) {
                self.ch4_freq_timer = 0;
                // LFSR step
                const xor_result = (self.ch4_lfsr ^ (self.ch4_lfsr >> 1)) & 1;
                self.ch4_lfsr = (self.ch4_lfsr >> 1) | (@as(u16, xor_result) << 14);
            }
        }
    }

    pub fn read(self: *const Audio, addr: u16) u8 {
        return switch (addr) {
            0xFF10 => self.ch1_sweep,
            0xFF11 => self.ch1_duty_len,
            0xFF12 => self.ch1_env,
            0xFF13 => self.ch1_freq_low,
            0xFF14 => self.ch1_freq_high,
            0xFF16 => self.ch2_duty_len,
            0xFF17 => self.ch2_env,
            0xFF18 => self.ch2_freq_low,
            0xFF19 => self.ch2_freq_high,
            0xFF1A => self.ch3_enable,
            0xFF1B => self.ch3_len,
            0xFF1C => self.ch3_volume,
            0xFF1D => self.ch3_freq_low,
            0xFF1E => self.ch3_freq_high,
            0xFF20 => self.ch4_len_env,
            0xFF21 => self.ch4_poly,
            0xFF22 => self.ch4_freq_ctrl,
            0xFF24 => self.master_volume,
            0xFF25 => self.sound_select,
            0xFF26 => self.sound_on,
            0xFF30...0xFF3F => self.wave_ram[addr - 0xFF30],
            else => 0xFF,
        };
    }

    pub fn write(self: *Audio, addr: u16, val: u8) void {
        switch (addr) {
            0xFF10 => self.ch1_sweep = val,
            0xFF11 => self.ch1_duty_len = val,
            0xFF12 => self.ch1_env = val,
            0xFF13 => self.ch1_freq_low = val,
            0xFF14 => {
                self.ch1_freq_high = val;
                if ((val & 0x80) != 0) {
                    self.ch1_enabled = true;
                    self.ch1_freq_timer = 0;
                    self.ch1_phase = 0;
                }
            },
            0xFF16 => self.ch2_duty_len = val,
            0xFF17 => self.ch2_env = val,
            0xFF18 => self.ch2_freq_low = val,
            0xFF19 => {
                self.ch2_freq_high = val;
                if ((val & 0x80) != 0) {
                    self.ch2_enabled = true;
                    self.ch2_freq_timer = 0;
                    self.ch2_phase = 0;
                }
            },
            0xFF1A => {
                self.ch3_enable = val;
                self.ch3_enabled = (val & 0x80) != 0;
            },
            0xFF1B => self.ch3_len = val,
            0xFF1C => self.ch3_volume = val,
            0xFF1D => self.ch3_freq_low = val,
            0xFF1E => {
                self.ch3_freq_high = val;
                if ((val & 0x80) != 0) {
                    self.ch3_enabled = true;
                    self.ch3_freq_timer = 0;
                    self.ch3_wave_index = 0;
                }
            },
            0xFF20 => self.ch4_len_env = val,
            0xFF21 => self.ch4_poly = val,
            0xFF22 => {
                self.ch4_freq_ctrl = val;
                if ((val & 0x80) != 0) {
                    self.ch4_enabled = true;
                    self.ch4_freq_timer = 0;
                    self.ch4_lfsr = 0x7FFF;
                }
            },
            0xFF24 => self.master_volume = val,
            0xFF25 => self.sound_select = val,
            0xFF26 => {
                self.sound_on = val;
                if ((val & 0x80) == 0) {
                    // Sound off: disable all channels
                    self.ch1_enabled = false;
                    self.ch2_enabled = false;
                    self.ch3_enabled = false;
                    self.ch4_enabled = false;
                }
            },
            0xFF30...0xFF3F => self.wave_ram[addr - 0xFF30] = val,
            else => {},
        }
    }

    pub fn getSample(self: *const Audio) f32 {
        var sample: f32 = 0.0;
        const duty_cycles = [_]u8{ 1, 2, 4, 6 };

        // Channel 1: Square wave
        if (self.ch1_enabled) {
            const duty = (self.ch1_duty_len >> 6) & 0x03;
            const duty_cycle = duty_cycles[duty];
            const output = if (self.ch1_phase < duty_cycle) @as(f32, 1.0) else @as(f32, -1.0);
            sample += output * 0.25;
        }

        // Channel 2: Square wave
        if (self.ch2_enabled) {
            const duty = (self.ch2_duty_len >> 6) & 0x03;
            const duty_cycle = duty_cycles[duty];
            const output = if (self.ch2_phase < duty_cycle) @as(f32, 1.0) else @as(f32, -1.0);
            sample += output * 0.25;
        }

        // Channel 3: Wave output
        if (self.ch3_enabled) {
            const wave_byte = self.wave_ram[self.ch3_wave_index / 2];
            const nibble = if ((self.ch3_wave_index & 1) == 0)
                (wave_byte >> 4) & 0x0F
            else
                wave_byte & 0x0F;
            const normalized = (@as(f32, nibble) / 15.0) * 2.0 - 1.0;
            sample += normalized * 0.25;
        }

        // Channel 4: Noise
        if (self.ch4_enabled) {
            const output = if ((self.ch4_lfsr & 1) == 0) @as(f32, 1.0) else @as(f32, -1.0);
            sample += output * 0.25;
        }

        return sample;
    }

    fn getFrequency(_: *const Audio, freq_low: u8, freq_high: u8) u16 {
        const low = @as(u16, freq_low);
        const high = @as(u16, freq_high & 0x07);
        return low | (high << 8);
    }
};
