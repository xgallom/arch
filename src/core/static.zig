const std = @import("std");
const options = @import("root").cathode_run_options;

const game = @import("game.zig");
const unit = @import("unit.zig");

pub const sym = struct {
    pub const empty = ' ';
    pub const gnds = [_]u8{ ' ', '.' };
    pub const ramp_fwd = '/';
    pub const ramp_bwd = '\\';
    pub const wall = '#';

    pub const blocks = [_]u8{
        empty,
        0xB0,
        0xB1,
        0xB2,
        0xDB,
    };

    pub const sgl_walls = [_]u8{
        empty,
        empty,
        empty,
        0xC0,
        empty,
        0xB3,
        0xDA,
        0xC3,
        empty,
        0xD9,
        0xC4,
        0xC2,
        0xBF,
        0xB4,
        0xC2,
        0xC5,
    };

    pub const dbl_walls = [_]u8{
        empty,
        empty,
        empty,
        0xC8,
        empty,
        0xBA,
        0xC9,
        0xCC,
        empty,
        0xBC,
        0xCD,
        0xCA,
        0xBB,
        0xB9,
        0xCB,
        0xCE,
    };

    pub fn dblWallsLookup(s: u8) game.Dir.Flags {
        return dbl_walls_lut[s];
    }

    const dbl_walls_lut = blk: {
        var lut: [256]game.Dir.Flags = @splat(0); // Default to 0
        lut[0xC8] = 0x3;
        lut[0xBA] = 0x5;
        lut[0xC9] = 0x6;
        lut[0xCC] = 0x7;
        lut[0xBC] = 0x9;
        lut[0xCD] = 0xA;
        lut[0xCA] = 0xB;
        lut[0xBB] = 0xC;
        lut[0xB9] = 0xD;
        lut[0xCB] = 0xE;
        lut[0xCE] = 0xF;
        break :blk lut;
    };
};
