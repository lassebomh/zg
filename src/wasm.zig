const std = @import("std");
const utils = @import("./utils.zig");
const ctx = @import("./canvas.zig");

const inputs = @import("./inputs.zig");

const RGBA = utils.RGBA;
const v2 = utils.v2;

extern fn jsLogf32(n: f32) void;
extern fn jsLogu64(n: u64) void;
extern fn jsLogu32(n: i32) void;

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

export fn main() void {}

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

    move = v2.normalize(move) * v2.fill(15);

    g.pos += move;

    g.mouse = inp.mouse - inp.screen / v2.fill(2);
}

fn render(prev: *State, curr: *State, alpha: f32, screen: v2.Value) void {
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
    // jsLogf32(pos[0]);
    // jsLogf32(pos[1]);
}

const State = struct {
    pos: v2.Value,
    mouse: v2.Value,
};

var prev_seen_tick: i32 = 0;

var prev_state: State = .{
    .pos = v2.zero,
    .mouse = v2.zero,
};
var curr_state: State = .{
    .pos = v2.zero,
    .mouse = v2.zero,
};

export fn frame(timeOffset: i32, screenWidth: i32, screenHeight: i32) void {
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
    }

    render(&prev_state, &curr_state, alpha, screen);
}
