const std = @import("std");
const utils = @import("./utils.zig");
const ctx = @import("./canvas.zig");
const Container = @import("./container.zig").Container;

const inp = @import("./inputs.zig");

const RGBA = utils.RGBA;
const v2 = utils.v2;

const TICK_RATE = 1000.0 / 60.0;

extern fn jsLogStr(ptr: [*]u8, len: u32) void;
pub fn log(comptime fmt: []const u8, args: anytype) void {
    const slice = std.fmt.allocPrint(std.heap.wasm_allocator, fmt, args) catch unreachable;
    jsLogStr(slice.ptr, slice.len);
    std.heap.wasm_allocator.free(slice);
}
pub fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    log(fmt, args);
    unreachable;
}

fn update_boxes(boxes: *BoxContainer) void {
    for (boxes.items[0..boxes.len]) |*box| {
        box.pos += box.vel;
    }
}

const Box = struct {
    pos: v2.Value,
    size: v2.Value,
    vel: v2.Value,
    static: bool,

    fn topleft(this: *Box) v2.Value {
        return this.pos - this.size / v2.fill(2);
    }

    fn render(this: *Box, prev: *Box, alpha: f32) void {
        const pos = v2.lerp(prev.topleft(), this.topleft(), v2.fill(alpha));
        // const vel = v2.lerp(prev.vel, this.vel, alpha);
        const size = v2.lerp(prev.size, this.size, v2.fill(alpha));

        ctx.save();
        defer ctx.restore();

        ctx.lineWidth(1);
        if (this.static) {
            ctx.strokeStyle(RGBA.fromHex("#0000ff"));
        } else {
            ctx.strokeStyle(RGBA.fromHex("#ff0000"));
        }
        ctx.strokeRect(pos, size);
    }
};

const BoxContainer = Container(Box, 32);

const Avatar = struct {
    id: usize,
    inputs: struct {
        lstick: v2.Value,
        rstick: v2.Value,
    },

    torso_id: usize,
    fn get_torso(this: *Avatar, g: *State) *Box {
        return g.boxes.get(this.torso_id).?;
    }

    fn update(this: *Avatar, g: *State) void {
        var torso = this.get_torso(g);
        torso.vel += this.inputs.lstick * v2.fill(0.5);
        torso.vel /= v2.fill(1.3);
    }
};
const AvatarContainer = Container(Avatar, inp.MaxPeers); // should multiply if controllers are supported

const Player = struct {
    id: usize,
    peer_id: i32,
    avatar_id: ?usize,
    inputs: inp.Inputs,

    fn upsert_avatar(this: *Player, g: *State) *Avatar {
        const avatar_id = this.avatar_id orelse init: {
            var avatarEntry = g.avatars.new();
            avatarEntry.item.id = avatarEntry.id;

            const torsoEntry = g.boxes.new();
            avatarEntry.item.torso_id = torsoEntry.id;
            torsoEntry.item.pos = v2.zero;
            torsoEntry.item.size = v2.fill(10);

            // avatarEntry.item.*.torso = Box{
            //     .pos = v2.zero,
            //     .size = v2.fill(1),
            //     .vel = v2.zero,
            // };
            this.avatar_id = avatarEntry.id;
            break :init avatarEntry.id;
        };

        return g.avatars.get(avatar_id).?;
    }

    fn update(this: *Player, g: *State) void {
        var avatar = this.upsert_avatar(g);

        var lstick = v2.zero;
        if (this.inputs.a) lstick[0] -= 1;
        if (this.inputs.d) lstick[0] += 1;
        if (this.inputs.w) lstick[1] -= 1;
        if (this.inputs.s) lstick[1] += 1;
        avatar.inputs.lstick = v2.clamp_length(lstick, 1);

        var rstick = v2.zero;

        if (this.inputs.a) rstick[0] -= 1;
        if (this.inputs.d) rstick[0] += 1;
        if (this.inputs.w) rstick[1] -= 1;
        if (this.inputs.s) rstick[1] += 1;
        avatar.inputs.rstick = v2.clamp_length(rstick, 1);
    }
};
const PlayerContainer = Container(Player, inp.MaxPeers);

const State = struct {
    avatars: AvatarContainer,
    players: PlayerContainer,
    boxes: BoxContainer,

    fn update(this: *State, peersInputs: []inp.Inputs) void {
        for (peersInputs) |inputs| {
            if (inputs.peer_id == 0) continue;

            var player: *Player = find_player: {
                for (this.players.items[0..this.players.len]) |*p| {
                    if (p.peer_id == inputs.peer_id) {
                        break :find_player p;
                    }
                }

                var newPlayer = this.players.new();

                newPlayer.item.id = newPlayer.id;
                newPlayer.item.peer_id = inputs.peer_id;

                break :find_player newPlayer.item;
            };
            player.inputs = inputs;
            player.update(this);
        }

        for (this.avatars.items[0..this.avatars.len]) |*avatar| {
            avatar.update(this);
        }
        update_boxes(&this.boxes);
    }

    fn render(this: *State, prev: *State, alpha: f32, screen: v2.Value) void {
        defer ctx.flush();

        ctx.save();
        defer ctx.restore();

        ctx.clearRect(v2.zero, screen);

        ctx.fillStyle(RGBA.fromHex("#000000"));
        ctx.fillRect(v2.zero, screen);

        ctx.translate(screen / v2.fill(2));
        ctx.scale(v2.fill(5));

        for (0..this.boxes.len) |box_i| {
            const box = &this.boxes.items[box_i];
            const box_id = this.boxes.ids[box_i];

            const prevbox = prev.boxes.get(box_id) orelse continue;
            box.render(prevbox, alpha);
        }
    }

    fn init() State {
        var state: State = .{
            .avatars = AvatarContainer.init(),
            .players = PlayerContainer.init(),
            .boxes = BoxContainer.init(),
        };

        const ground = state.boxes.new();
        ground.item.size = v2.xy(100, 20);
        ground.item.pos = v2.xy(0, 20);
        ground.item.static = true;

        return state;
    }
};

var prev_seen_tick: i32 = 0;
var prev_state: ?State = null;

var curr_state: State = State.init();

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
        curr_state.update(&inp.peersInputs);
        // if (itick == 100) {
        // log("{}", .{inputs.inputs.mouse});
        // }
    }

    curr_state.render(&(prev_state orelse curr_state), alpha, screen);
}

export fn main() void {
    log("{}", .{@sizeOf(State)});
}
