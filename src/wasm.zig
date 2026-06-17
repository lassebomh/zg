const std = @import("std");
const utils = @import("./utils.zig");
const ctx = @import("./canvas.zig");
const Container = @import("./container.zig").Container;

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

export fn main() void {}

const TICK_RATE = 1000.0 / 60.0;

fn tick(g: *State, inp: *inputs.Inputs) void {
    if (g.players.len == 0) {
        const playerEntry = g.players.new();
        playerEntry.item.* = .{
            .id = playerEntry.id,
            .player_id = null,
            .primary = v2.zero,
            .secondary = v2.zero,
        };
    }

    if (g.avatars.len == 0) {
        const avatarEntry = g.avatars.new();

        avatarEntry.item.* = .{
            .id = avatarEntry.id,
            .pos = v2.zero,
            .vel = v2.zero,
        };
    }

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

    move = v2.clamp_length(move, 1) * v2.fill(10);

    for (0..g.avatars.len) |x| {
        var avatar = &g.avatars.items[x];

        avatar.vel += move;
        avatar.pos += avatar.vel;
        avatar.vel /= v2.fill(1.3);
    }
}

fn render(prev: *State, curr: *State, alpha: f32, screen: v2.Value) void {
    defer ctx.flush();

    ctx.save();
    defer ctx.restore();
    ctx.clearRect(v2.zero, screen);

    ctx.fillStyle(RGBA.fromHex("#000000"));
    ctx.fillRect(v2.zero, screen);

    ctx.translate(screen / v2.fill(2));

    for (curr.avatars.items[0..curr.avatars.len]) |avatar| {
        const prevAvatar = prev.avatars.get(avatar.id) orelse continue;
        const pos = v2.lerp(prevAvatar.pos, avatar.pos, v2.fill(alpha));
        ctx.fillStyle(RGBA.fromHex("#ff0000"));
        ctx.fillRect(pos, v2.xy(10, 10));
    }
}

const Avatar = struct {
    id: usize,
    pos: v2.Value,
    vel: v2.Value,
};
const AvatarContainer = Container(Avatar, 16);

const Player = struct {
    id: usize,
    player_id: ?usize,

    primary: v2.Value,
    secondary: v2.Value,
};
const PlayerContainer = Container(Player, 16);

const State = struct {
    avatars: AvatarContainer,
    players: PlayerContainer,
};

var prev_seen_tick: i32 = 0;
var prev_state: ?State = null;

var curr_state: State = .{
    .avatars = AvatarContainer.init(),
    .players = PlayerContainer.init(),
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
