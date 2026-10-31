const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const math = @import("zengine").math;

// const Txt = @import("Txt.zig");

const log = std.log.scoped(.game);

pub const SessionState = enum(u32) {
    start,
    end,
    menu,
    settings,
    init,
    quit,
    died,
    intro,
    running,
    paused,
};
