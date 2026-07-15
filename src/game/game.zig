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

        camera_pos: lib.SecondOrder(m.Vec3) = .init(5, 3, 0),

        pub fn init(ctx: *GLContext, state: *State) Render {
            return .{
                .ctx = ctx,
                .avatars = .init(),
                .state = state,
                .dt = 0,
                .tick = 0,
            };
        }

        pub fn render(this: *Render, gpa: std.mem.Allocator, state: *State, screen: m.Vec2, tick: f32, peer_id: i32) !void {
            this.state = state;

            const prevTick = this.tick;
            this.tick = tick;
            this.dt = (this.tick - prevTick) * State.TickRate;

            // cleanup deleted avatars
            const len = this.avatars.len;
            for (0..len) |i| {
                const renderAvatar = &this.avatars.items[len - i - 1];
                if (this.state.avatars.get(renderAvatar.id) == null) {
                    this.avatars.delete(renderAvatar.id);
                }
            }

            // begin render
            try this.ctx.cube.add(gpa, m.Mat4x4.translate(.init(0, 0, 0)).mul(.scale(.init(6, 0.001, 6))), .init(1, 1, 1, 1));

            for (this.state.avatars.iter()) |avatar| {
                // create the avatar if it doesn't exist
                var renderAvatar = this.avatars.get(avatar.id) orelse brk: {
                    const newAvatar = try this.avatars.addOne();
                    newAvatar.* = .init(this, avatar);
                    break :brk newAvatar;
                };

                try renderAvatar.render(this, gpa);
            }

            // move camera to current avatar
            var peerAvatar: ?game.Avatar = null;
            for (this.state.players.iter()) |player| {
                if (player.peer_id == peer_id) {
                    for (this.state.avatars.iter()) |avatar| {
                        if (avatar.id == player.avatar_id) {
                            peerAvatar = avatar;
                            break;
                        }
                    }
                    break;
                }
            }
            if (peerAvatar) |avatar| {
                this.camera_pos.update(this.dt, avatar.position);
            }

            const aspectRatio = screen.x() / screen.y();

            const scale: f32 = 6;
            // const scale: f32 = 2;

            try this.ctx.render(.{
                .view = m.Mat4x4.translate(
                    .init(0, 0, -10),
                ).mul(
                    // .rotateX(0.3),
                    .rotateX(0.9),
                ).mul(
                    .translate(.init(-this.camera_pos.value.x(), -1, -this.camera_pos.value.y())),
                ),
                .projection = .projection2D(.{
                    .left = -scale * aspectRatio,
                    .right = scale * aspectRatio,
                    .bottom = -scale,
                    .top = scale,
                    .near = 0.01,
                    .far = 25,
                }),
                .screen = screen,
            });
        }
    };
};
