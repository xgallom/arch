const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const cathode_run_options = @import("root").cathode_run_options;

const zengine = @import("zengine");
const math = zengine.math;

const game = @import("game.zig");
const prng = @import("prng.zig");
const static = @import("static.zig");
const Txt = @import("Txt.zig");

const log = std.log.scoped(.types);

pub const Dir = enum {
    up,
    right,
    down,
    left,

    const flags = math.int.Flags(@This());
    pub const Flags = flags.U;
    pub const none = flags.none;
    pub const one = flags.one;
    pub const many = flags.many;
    pub const all = many(&.{ .up, .right, .down, .left });
};

pub const Color = enum {
    red,
    green,
    blue,
    bold,

    const flags = math.int.Flags(@This());
    pub const Flags = flags.U;
    pub const none = flags.none;
    pub const one = flags.one;
    pub const many = flags.many;
};

pub const CellAttr = packed struct(u8) {
    bg: Color.Flags = Color.none,
    fg: Color.Flags = Color.none,

    pub const none: @This() = .{};

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("bg: {x:02}, fg: {x:02}", .{ self.bg, self.fg });
    }
};

pub const InputEvent = enum {
    none,
    err,
    key_down,
    key_up,
    mouse_move,
    mouse_down,
    mouse_up,
};

pub const InputResult = struct {
    event: InputEvent,
    data: union {
        none: void,
        key: Key,
        mouse: struct {
            x: u32,
            y: u32,
            rel_x: f32,
            rel_y: f32,
        },
    },

    pub const Key = struct {
        keycode: u32 = 0,
    };

    pub const none: @This() = .{ .event = .none, .data = .{ .none = {} } };
    pub const err: @This() = .{ .event = .err, .data = .{ .none = {} } };

    pub fn keyDown(keycode: u32) @This() {
        return .{ .event = .key_down, .data = .{ .key = .{ .keycode = keycode } } };
    }

    pub fn keyUp(keycode: u32) @This() {
        return .{ .event = .key_up, .data = .{ .key = .{ .keycode = keycode } } };
    }

    pub fn mouseMove(x: u32, y: u32, rel_x: f32, rel_y: f32) @This() {
        return .{ .event = .mouse_move, .data = .{
            .mouse = .{
                .x = x,
                .y = y,
                .rel_x = rel_x,
                .rel_y = rel_y,
            },
        } };
    }

    pub fn mouseDown(x: u32, y: u32, rel_x: f32, rel_y: f32) @This() {
        return .{ .event = .mouse_down, .data = .{
            .mouse = .{
                .x = x,
                .y = y,
                .rel_x = rel_x,
                .rel_y = rel_y,
            },
        } };
    }

    pub fn mouseUp(x: u32, y: u32, rel_x: f32, rel_y: f32) @This() {
        return .{ .event = .mouse_up, .data = .{
            .mouse = .{
                .x = x,
                .y = y,
                .rel_x = rel_x,
                .rel_y = rel_y,
            },
        } };
    }

    pub fn isKey(self: @This(), keys: []const u32) bool {
        assert(self.event == .key_down or self.event == .key_up);
        const keycode = self.data.key.keycode;
        return for (keys) |key| {
            if (key == keycode) break true;
        } else false;
    }
};

pub const Frame = struct {
    syms: []u8,
    attrs: []CellAttr,
    duration: u64 = undefined,

    pub fn init(gpa: Allocator, win_size: math.Point_u32) !@This() {
        const win_area: usize = @intCast(win_size[0] * win_size[1]);
        const syms = try gpa.alloc(u8, win_area);
        errdefer gpa.free(syms);
        const attrs = try gpa.alloc(game.CellAttr, win_area);
        errdefer gpa.free(attrs);
        @memset(syms, 0);
        @memset(attrs, .none);
        return .{ .syms = syms, .attrs = attrs };
    }

    pub fn deinit(self: *@This(), gpa: Allocator) void {
        gpa.free(self.syms);
        gpa.free(self.attrs);
    }

    pub fn txt(self: *const @This()) Txt {
        return .{ .head = self.syms.ptr, .tail = self.syms.ptr, .capacity = .B(self.syms.len) };
    }

    pub fn clear(self: *const @This()) void {
        @memset(self.syms, static.sym.empty);
        @memset(self.attrs, .none);
    }

    pub fn set(self: *const @This(), sym: u8, attr: CellAttr, idx: usize) void {
        assert(idx < self.syms.len);
        assert(self.syms.len == self.attrs.len);
        self.syms[idx] = sym;
        self.attrs[idx] = attr;
    }

    pub fn setSym(self: *const @This(), sym: u8, idx: usize) void {
        assert(idx < self.syms.len);
        self.syms[idx] = sym;
    }

    pub fn write(self: *const @This(), syms: []const u8, attr: CellAttr, idx: usize) void {
        assert(idx + syms.len <= self.syms.len);
        assert(self.syms.len == self.attrs.len);
        @memcpy(self.syms[idx .. idx + syms.len], syms);
        @memset(self.attrs[idx .. idx + syms.len], attr);
    }

    pub fn fill(self: *const @This(), len: usize, sym: u8, attr: CellAttr, idx: usize) void {
        assert(idx + len <= self.syms.len);
        assert(self.syms.len == self.attrs.len);
        @memset(self.syms[idx .. idx + len], sym);
        @memset(self.attrs[idx .. idx + len], attr);
    }

    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        assert(self.syms.len == self.attrs.len);
        for (0..self.syms.len) |n| {
            try writer.print(
                "{}: {x:02} {x:02} {x:02}  ",
                .{ n, self.syms[n], self.attrs[n].bg, self.attrs[n].fg },
            );
            if (n % 16 == 0) try writer.writeByte('\n');
        }
    }
};
