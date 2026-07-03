const std = @import("std");

const Input = @import("../js/inputs.zig").Input;
const debug = @import("../js/debug.zig");

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const v2 = lib.v2;

const px = @import("../js/pixel.zig");
const RGBA = @import("../lib/root.zig").RGBA;

pub const State = struct {
    avatars: lib.Container(game.Avatar, game.MaxPlayers), // should multiply if controllers are supported,
    players: lib.Container(game.Player, game.MaxPlayers),
    level: game.Level,

    pub fn update(this: *State, inputs: []Input) void {
        for (inputs) |input| {
            if (input.peer_id == 0) continue;

            var player: *game.Player = upsert_player: {
                for (this.players.items[0..this.players.len]) |*p| {
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

        for (this.avatars.items[0..this.avatars.len]) |*avatar| {
            avatar.update(this);
        }
        // update_boxes(&this.boxes);
    }

    pub fn render(this: *State, screen: @Vector(2, i32), peer_id: i32) void {
        px.camera.size = screen;
        px.camera.size /= @splat(10);

        px.camera.pos = v2.zero;

        for (this.players.items) |player| {
            if (player.peer_id == peer_id) {
                const avatar = this.avatars.get(player.avatar_id orelse break).?;
                px.camera.pos = @floor(avatar.collision.cc());
            }
        }

        px.camera.pos -= .{ @divFloor(px.camera.size[0], 2), @divFloor(px.camera.size[1], 2) };

        px.begin();
        defer px.flush();

        // px.add_light(.{ .point = .{
        //     .color = RGBA.hex("#ffffff"),
        //     .pos = .{ 0, 0, 50 },
        //     .intensity = 500,
        // } });

        px.add_light(.{ .directional = .{
            .color = RGBA.hex("#ffffff"),
            .dir = .{ -0.1, 0.1, -1 },
            .intensity = 1,
        } });

        // px.Canvas.light_directional(
        //     .{ 1, 1, -1 },
        //     comptime RGBA.hex("#ffffff"),
        //     1.0,
        // );

        // var cam_iter = px.camera.iter();
        // while ((&cam_iter).next()) |pos| {
        //     px.put(pos, comptime RGBA.hex("#332211"));
        // }

        this.level.render();

        for (0..this.avatars.len) |avatar_i| {
            const avatar = &this.avatars.items[avatar_i];
            avatar.render();
        }
    }

    pub fn init() State {
        const state: State = .{
            .avatars = lib.Container(game.Avatar, game.MaxPlayers).init(),
            .players = lib.Container(game.Player, game.MaxPlayers).init(),
            .level = game.Level.init() catch |e| debug.fail(e),
        };

        return state;
    }
};
