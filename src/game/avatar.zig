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

    clockwise: bool,

    limb: struct {
        head_target: v2.Value,
        head: game.Box,
    },

    collision: game.Box,

    pub fn create(id: usize, pos: v2.Value) Avatar {
        return Avatar{
            .id = id,
            .inputs = .{
                .jump = false,
                .lstick = v2.zero,
                .rstick = v2.zero,
            },
            .clockwise = true,
            .collision = game.Box.init(pos, v2.xy(9, 9)),
            .limb = .{
                .head_target = v2.zero,
                .head = game.Box.init(pos, v2.xy(8, 8)),
            },
        };
    }

    pub fn update(this: *Avatar, g: *game.State) void {
        this.collision.vel[0] += this.inputs.lstick[0] * 0.5;
        this.collision.vel[0] /= 1.3;

        this.collision.vel[1] += 0.15;
        if (this.inputs.jump and this.collision.impact[1] < 0) {
            this.collision.vel[1] = -2;
        }

        this.collision.update(g);

        if (@abs(this.inputs.lstick[0]) > 0.1) {
            this.clockwise = this.inputs.lstick[0] > 0;
        }

        var body_angle: f32 = std.math.atan2(-3, this.collision.vel[0]);
        js.debug.log("{any}", .{body_angle});

        if (this.inputs.lstick[1] > 0.1) {
            if (this.clockwise) {
                body_angle = 0;
            } else {
                body_angle = -std.math.pi;
            }
        } else {
            body_angle = std.math.atan2(-5, this.collision.vel[0]);
        }

        this.limb.head_target = this.collision.cc() + (v2.radians(body_angle) * v2.fill(8));

        const head_target_vel = this.limb.head_target - this.limb.head.cc();
        this.limb.head.vel = head_target_vel;
        this.limb.head.update(g);
    }

    pub fn render(this: *Avatar, prev: *Avatar, alpha: f32) void {
        // js.ctx.beginPath();
        // js.ctx.save();
        // defer js.ctx.restore();
        // js.ctx.strokeStyle(RGBA.fromHex("#ff0000"));
        // js.ctx.lineWidth(6);
        // js.ctx.moveTo(v2.lerp(prev.collision.cc(), this.collision.cc(), v2.fill(alpha)) + v2.xy(0, 0));
        // js.ctx.lineTo(v2.lerp(prev.limb.head.cc(), this.limb.head.cc(), v2.fill(alpha)) + v2.xy(0, 0));
        // js.ctx.stroke();
        this.collision.render(prev.collision, RGBA.fromHex("#00ff00"), alpha);
        this.limb.head.render(prev.limb.head, RGBA.fromHex("#ff0000"), alpha);
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
            avatar.* = Avatar.create(avatar.id, v2.xy(0, 0));
            this.avatar_id = avatar.id;
            break :init avatar.id;
        };

        return g.avatars.get(avatar_id).?;
    }

    pub fn update(this: *Player, g: *game.State) void {
        if (this.input.space or this.avatar_id != null) {
            var avatar = this.upsert_avatar(g);

            var lstick = v2.zero;
            if (this.input.a) lstick[0] -= 1;
            if (this.input.d) lstick[0] += 1;
            if (this.input.w) lstick[1] -= 1;
            if (this.input.s) lstick[1] += 1;
            avatar.inputs.lstick = v2.clamp_length(lstick, 1);

            // var rstick = v2.zero;
            // if (this.input.a) rstick[0] -= 1;
            // if (this.input.d) rstick[0] += 1;
            // if (this.input.w) rstick[1] -= 1;
            // if (this.input.s) rstick[1] += 1;
            // avatar.inputs.rstick = v2.clamp_length(rstick, 1);

            avatar.inputs.jump = this.input.space;
        }
    }
};
