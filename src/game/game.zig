const std = @import("std");

const Input = @import("../js/inputs.zig").Input;
const debug = @import("../js/debug.zig");

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const v2 = lib.v2;

const Canvas = @import("../js/pixel.zig").Canvas;
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

    pub fn render(this: *State, screen: v2.Value, peer_id: i32) void {
        var camera_pos = v2.zero;

        for (this.players.items) |player| {
            if (player.peer_id == peer_id) {
                const avatar = this.avatars.get(player.avatar_id orelse break).?;
                camera_pos = avatar.collision.position;
            }
        }

        Canvas.begin(camera_pos, screen / v2.fill(8));
        defer Canvas.flush();

        Canvas.light_directional(.{ 1, 1, -1 }, comptime RGBA.fromHex("#ffffff"), 1.0);

        Canvas.box(
            Canvas.render_x0(),
            Canvas.render_y0(),
            Canvas.render_width(),
            Canvas.render_height(),
            1,
            comptime RGBA.fromHex("#222222"),
        );

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
