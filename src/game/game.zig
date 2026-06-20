const std = @import("std");
const js = @import("../js/root.zig");

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;

pub const State = struct {
    avatars: lib.Container(game.Avatar, game.MaxPlayers), // should multiply if controllers are supported,
    players: lib.Container(game.Player, game.MaxPlayers),
    level: game.Level,

    pub fn update(this: *State, peersInputs: []js.inputs.Inputs) void {
        for (peersInputs) |inputs| {
            if (inputs.peer_id == 0) continue;

            var player: *game.Player = find_player: {
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
        // update_boxes(&this.boxes);
    }

    pub fn render(this: *State, prev: *State, alpha: f32, screen: v2.Value, peer_id: i32) void {
        defer js.ctx.flush();

        js.ctx.save();
        defer js.ctx.restore();

        js.ctx.clearRect(v2.zero, screen);

        js.ctx.fillStyle(RGBA.fromHex("#000000"));
        js.ctx.fillRect(v2.zero, screen);

        js.ctx.translate(screen / v2.fill(2));
        js.ctx.scale(v2.fill(5));

        for (this.players.items) |player| {
            if (player.peer_id == peer_id) {
                const avatar = this.avatars.get(player.avatar_id orelse break).?;
                const prevAvatar = prev.avatars.get(avatar.id) orelse avatar;
                const pos = v2.lerp(prevAvatar.lower.position, avatar.lower.position, v2.fill(alpha));
                js.ctx.translate(-pos);
                break;
            }
        }

        this.level.render();

        for (0..this.avatars.len) |avatar_i| {
            const avatar = &this.avatars.items[avatar_i];
            const avatar_id = this.avatars.ids[avatar_i];

            const prev_avatar = prev.avatars.get(avatar_id) orelse continue;
            avatar.render(prev_avatar, alpha);
        }
    }

    pub fn init() State {
        const state: State = .{
            .avatars = lib.Container(game.Avatar, game.MaxPlayers).init(),
            .players = lib.Container(game.Player, game.MaxPlayers).init(),
            .level = game.Level.init(),
        };

        return state;
    }
};
