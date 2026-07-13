const std = @import("std");

const debug = @import("../js/debug.zig");
const Input = @import("../js/inputs.zig").Input;
const GLContext = @import("../js/wgl2_context.zig").GLContext;
const ObjMesh = @import("../lib/obj.zig").ObjMesh;
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;
const m = @import("../math/main.zig");
const game = @import("./root.zig");

pub const State = struct {
    avatars: lib.Container(game.Avatar, MaxPlayers), // should multiply if controllers are supported,
    players: lib.Container(game.Player, MaxPlayers),
    level: game.Level,

    pub const MaxPlayers = 16;
    pub const TickRate: comptime_float = 1000 / 60;

    pub fn update(this: *State, inputs: []Input) void {
        for (inputs) |input| {
            if (input.peer_id == 0) continue;

            var player: *game.Player = upsert_player: {
                for (this.players.iter()) |*p| {
                    if (p.peer_id == input.peer_id) {
                        break :upsert_player p;
                    }
                }

                const new_player = this.players.addOne() catch |e| debug.fail(e);

                new_player.id = new_player.id;
                new_player.peer_id = input.peer_id;

                break :upsert_player new_player;
            };
            player.input = input;
            player.update(this);
        }

        for (this.avatars.iter()) |*avatar| {
            avatar.update(this);
        }
        // update_boxes(&this.boxes);
    }

    pub fn init() State {
        const state: State = .{
            .avatars = lib.Container(game.Avatar, MaxPlayers).init(),
            .players = lib.Container(game.Player, MaxPlayers).init(),
            .level = game.Level.init() catch |e| debug.fail(e),
        };

        return state;
    }

    pub const Render = struct {
        ctx: *GLContext,

        state: *State,

        tick: f32,
        dt: f32,

        avatars: lib.Container(game.Avatar.Render, MaxPlayers),

        pub fn init(ctx: *GLContext, state: *State) Render {
            return .{
                .ctx = ctx,
                .avatars = .init(),
                .state = state,
                .dt = 0,
                .tick = 0,
            };
        }

        pub fn render(this: *Render, gpa: std.mem.Allocator, state: *State, width: i32, height: i32, tick: i32, alpha: f32) !void {
            const prevTick = this.tick;
            this.tick = @floatFromInt(tick);
            this.tick += alpha;

            this.dt = (this.tick - prevTick) * State.TickRate;
            this.state = state;

            for (this.avatars.iter()) |renderAvatar| {
                if (this.state.avatars.get(renderAvatar.id) == null) {
                    this.avatars.delete(renderAvatar.id);
                }
            }

            try this.ctx.cube.add(gpa, m.Mat4x4.translate(.init(0, -2, 0)).mul(.scale(.init(6, 1, 6))), .init(1, 1, 1, 1));

            for (this.state.avatars.iter()) |avatar| {
                var renderAvatar = this.avatars.get(avatar.id) orelse brk: {
                    const newAvatar = try this.avatars.addOne();
                    newAvatar.* = .init(this, avatar);
                    break :brk newAvatar;
                };

                try renderAvatar.draw(this, gpa);
            }

            const aspectRatio = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));

            try this.ctx.render(.{
                .view = m.Mat4x4.translate(.init(0, 0, -10)).mul(.rotateX(0.9)).mul(.rotateY(0)),
                .projection = .projection2D(.{
                    .left = -6 * aspectRatio,
                    .right = 6 * aspectRatio,
                    .bottom = -6,
                    .top = 6,
                    .near = 0.01,
                    .far = 25,
                }),
                .width = width,
                .height = height,
            });
        }
    };
};
