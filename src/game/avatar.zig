const std = @import("std");

const js = @import("../js/root.zig");
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;
const m = @import("../math/main.zig");
const game = @import("./root.zig");

pub const Avatar = struct {
    id: usize,
    inputs: struct {
        jump: bool,
        lstick: v2.Value,
        rstick: v2.Value,
    },

    position: m.Vec2,

    pub fn create(id: usize) Avatar {
        return Avatar{
            .id = id,
            .inputs = .{
                .jump = false,
                .lstick = v2.zero,
                .rstick = v2.zero,
            },
            .position = .init(0, 0),
        };
    }

    pub fn update(this: *Avatar, g: *game.State) void {
        _ = g; // autofix
        this.position.v[0] += this.inputs.lstick[0] * 0.1;
        this.position.v[1] += this.inputs.lstick[1] * 0.1;
    }

    pub const Render = struct {
        id: usize,

        pos: lib.SecondOrder(m.Vec3),

        pub fn init(g: *game.State.Render, avatar: Avatar) Render {
            _ = g; // autofix
            return .{
                .id = avatar.id,
                .pos = .init(3, 0.1, 0),
            };
        }

        pub fn draw(this: *Render, g: *game.State.Render, gpa: std.mem.Allocator) !void {
            const avatar = g.state.avatars.get(this.id).?;

            this.pos.update(g.dt, .init(avatar.position.x(), 0, avatar.position.y()));

            const model = m.Mat4x4.translate(this.pos.value);

            try g.ctx.cylinder.add(gpa, model, .init(1, 0, 0, 1));
        }
    };
};

pub const Player = struct {
    id: usize,
    peer_id: i32,
    avatar_id: ?usize,
    input: js.inputs.Input,

    pub fn upsert_avatar(this: *Player, g: *game.State) *Avatar {
        const avatar_id = this.avatar_id orelse init: {
            const avatar = g.avatars.addOne() catch |e| js.debug.fail(e);
            avatar.* = Avatar.create(avatar.id);
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
