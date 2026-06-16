const std = @import("std");
const utils = @import("./utils.zig");
const ctx = @import("./canvas.zig");

const inputs = @import("./inputs.zig");

const RGBA = utils.RGBA;
const v2 = utils.v2;

extern fn jsLogStr(ptr: [*]u8, len: u32) void;

const Input = struct {
    w: bool,
    a: bool,
    s: bool,
    d: bool,
    screen: v2.Value,
    mouse: v2.Value,
    mouse_left: bool,
    mouse_right: bool,
    mouse_middle: bool,
};

const wal = std.heap.wasm_allocator;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    const slice = std.fmt.allocPrint(wal, fmt, args) catch unreachable;
    jsLogStr(slice.ptr, slice.len);
    wal.free(slice);
}

export fn main() void {
    // const alloc = wal.alloc(*const u8, 14) catch unreachable;
    const states = States.init();
    log("{}\n", .{states});
}

const TICK_RATE = 1000.0 / 60.0;

fn tick(g: *State, inp: *inputs.Inputs) void {
    var move = v2.zero;

    if (inp.a != 0) {
        move[0] -= 1;
    }
    if (inp.d != 0) {
        move[0] += 1;
    }
    if (inp.w != 0) {
        move[1] -= 1;
    }
    if (inp.s != 0) {
        move[1] += 1;
    }

    move = v2.clamp_length(move, 1) * v2.fill(15);

    g.pos += move;

    g.mouse = inp.mouse - inp.screen / v2.fill(2);
}

fn render(prev: *const State, curr: *const State, alpha: f32, screen: v2.Value) void {
    defer ctx.flush();

    ctx.save();
    defer ctx.restore();
    ctx.clearRect(v2.zero, screen);

    ctx.fillStyle(RGBA.fromHex("#000000"));
    ctx.fillRect(v2.zero, screen);

    ctx.translate(screen / v2.fill(2));

    const pos = v2.lerp(prev.pos, curr.pos, v2.fill(alpha));
    ctx.fillStyle(RGBA.fromHex("#ff0000"));
    ctx.fillRect(pos, v2.xy(30, 30));

    const mouse = v2.lerp(prev.mouse, curr.mouse, v2.fill(alpha));
    ctx.fillStyle(RGBA.fromHex("#2288cc"));
    ctx.fillRect(mouse, v2.xy(15, 15));
}

fn Container(comptime T: type, comptime capacity: comptime_int) type {
    const TContainer = struct {
        const Self = @This();

        ids: [capacity]i32,
        ixs: [capacity]i32,
        items: [capacity]T,
        len: i32,

        fn init() Self {
            var out = Self{
                .ids = undefined,
                .ixs = undefined,
                .items = undefined,
                .len = 0,
            };

            for (0..capacity) |x| {
                out.ids[x] = @intCast(x);
                out.ixs[x] = @intCast(x);
            }

            return out;
        }

        fn new(self: *Self) i32 {
            if (self.len == capacity) unreachable;
            self.len += 1;
            // return self.

            // idxs[id] = index

            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 0, 0, 0
            // len: 0
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 7, 0, 0
            // len: 1
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 7, 6, 0
            // len: 2
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 7, 6, 9
            // len: 3
            //
            // index: 0, 2, 1
            // ids:   0, 2, 1
            // items: 7, 9, 0
            // len: 2
            //
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 0, 0, 0
            // len: 0
            //
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 0, 0, 0
            // len: 0
            //
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 0, 0, 0
            // len: 0
            //
            // index: 0, 1, 2
            // ids:   0, 1, 2
            // items: 0, 0, 0
            // len: 0
            //
            //

        }
    };

    return TContainer;
}

const State = struct {
    pos: v2.Value,
    mouse: v2.Value,
};

const States = Container(State, 4);

var prev_seen_tick: i32 = 0;

var prev_state: ?State = null;

var curr_state: State = .{
    .pos = v2.zero,
    .mouse = v2.zero,
};

export fn onAnimationFrame(timeOffset: i32, screenWidth: i32, screenHeight: i32) void {
    const screen: v2.Value = .{
        @floatFromInt(screenWidth),
        @floatFromInt(screenHeight),
    };

    const ftick: f32 = @as(f32, @floatFromInt(timeOffset)) / TICK_RATE;
    const itick: i32 = @trunc(ftick);
    const alpha = ftick - @floor(ftick);

    if (itick != prev_seen_tick) {
        prev_seen_tick = itick;

        prev_state = curr_state;
        tick(&curr_state, &inputs.inputs);
        // if (itick == 100) {
        // log("{}", .{inputs.inputs.mouse});
        // }
    }

    render(&(prev_state orelse curr_state), &curr_state, alpha, screen);
}
