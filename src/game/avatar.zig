const std = @import("std");
const js = @import("../js/root.zig");

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;

pub const MaxPlayers = 16;

pub const Avatar = struct {
    id: usize,
    inputs: struct {
        jump: bool,
        lstick: v2.Value,
        rstick: v2.Value,
    },

    box: game.Box,

    pub fn update(this: *Avatar, g: *game.State) void {
        this.box.vel[0] += this.inputs.lstick[0] * 0.5;
        this.box.vel[0] /= 1.3;

        this.box.vel[1] += 0.15;
        if (this.inputs.jump and this.box.impact[1] < 0) {
            this.box.vel[1] = -2;
        }

        this.box.update(g);
    }

    pub fn render(this: *Avatar, prev: *Avatar, alpha: f32) void {
        this.box.render(prev.box, alpha);
    }
};

pub const Player = struct {
    id: usize,
    peer_id: i32,
    avatar_id: ?usize,
    input: js.inputs.Input,

    pub fn upsert_avatar(this: *Player, g: *game.State) *Avatar {
        const avatar_id = this.avatar_id orelse init: {
            const avatar = g.avatars.addOne() catch |e| js.debug.fail(e);
            this.avatar_id = avatar.id;
            avatar.box = game.Box.init(v2.xy(0, 0), v2.xy(10, 15));
            break :init avatar.id;
        };

        return g.avatars.get(avatar_id).?;
    }

    pub fn update(this: *Player, g: *game.State) void {
        var avatar = this.upsert_avatar(g);

        var lstick = v2.zero;
        if (this.input.a) lstick[0] -= 1;
        if (this.input.d) lstick[0] += 1;
        if (this.input.w) lstick[1] -= 1;
        if (this.input.s) lstick[1] += 1;
        avatar.inputs.lstick = v2.clamp_length(lstick, 1);

        var rstick = v2.zero;

        if (this.input.a) rstick[0] -= 1;
        if (this.input.d) rstick[0] += 1;
        if (this.input.w) rstick[1] -= 1;
        if (this.input.s) rstick[1] += 1;
        avatar.inputs.rstick = v2.clamp_length(rstick, 1);

        avatar.inputs.jump = this.input.space;
    }
};
