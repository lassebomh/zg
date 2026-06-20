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
    inputs: js.inputs.Inputs,

    pub fn upsert_avatar(this: *Player, g: *game.State) *Avatar {
        const avatar_id = this.avatar_id orelse init: {
            var avatarEntry = g.avatars.addOne();
            avatarEntry.item.id = avatarEntry.id;

            avatarEntry.item.box.position = v2.xy(0, 0);
            avatarEntry.item.box.size = v2.xy(10, 20);

            // avatarEntry.item.*.torso = Box{
            //     .pos = v2.zero,
            //     .size = v2.fill(1),
            //     .vel = v2.zero,
            // };
            this.avatar_id = avatarEntry.id;
            break :init avatarEntry.id;
        };

        return g.avatars.getId(avatar_id).?;
    }

    pub fn update(this: *Player, g: *game.State) void {
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

        avatar.inputs.jump = this.inputs.space;
    }
};
