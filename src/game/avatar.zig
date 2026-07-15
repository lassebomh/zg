const std = @import("std");

const debug = @import("../js/debug.zig");
const js = @import("../js/root.zig");
const lib = @import("../lib/root.zig");
const v2 = lib.v2;
const m = @import("../math/main.zig");
const game = @import("./root.zig");

const avatarColors = [_]m.Vec4{
    .init(1, 0, 0, 1),
    .init(0, 1, 0, 1),
    .init(0, 0, 1, 1),
    .init(1, 1, 0, 1),
    .init(0, 1, 1, 1),
    .init(1, 0, 1, 1),
};

pub const Avatar = struct {
    id: usize,
    inputs: struct {
        jump: bool,
        lstick: m.Vec2,
        rstick: m.Vec2,
    },

    position: m.Vec2,

    pub fn create(id: usize) Avatar {
        return Avatar{
            .id = id,
            .inputs = .{
                .jump = false,
                .lstick = .init(0, 0),
                .rstick = .init(0, 0),
            },
            .position = .init(0, 0),
        };
    }

    pub fn update(this: *Avatar, g: *game.State) void {
        _ = g; // autofix

        this.position = this.position.add(&this.inputs.lstick.mulScalar(0.1));
    }

    pub const Render = struct {
        id: usize,

        pos: lib.SecondOrder(m.Vec3) = .init(4, 0.5, 1),
        dir: lib.SecondOrder(m.Vec2) = .init(3, 0.5, 0),
        lean: lib.SecondOrder(m.Vec2) = .init(2, 0.5, 0),
        walk: lib.SecondOrder(m.Vec2) = .init(7, 2, 0),
        walk_angle: f32 = 0,

        move_dir: m.Vec2 = .init(0, 0),

        pub fn init(g: *game.State.Render, avatar: Avatar) Render {
            _ = g; // autofix
            return .{ .id = avatar.id };
        }

        pub fn render(this: *Render, g: *game.State.Render, gpa: std.mem.Allocator) !void {
            const avatar = g.state.avatars.get(this.id).?;

            const color = avatarColors[avatar.id % avatarColors.len];

            this.pos.update(g.dt, .init(avatar.position.x(), 0, avatar.position.y()));

            if (avatar.inputs.lstick.len() > 0.1) {
                this.move_dir = m.Vec2.init(this.pos.velocity.x(), this.pos.velocity.z()).normalize(0.01);
                const target_dir = avatar.inputs.lstick.normalize(0.01);

                const dot = this.move_dir.dot(&target_dir);
                const cross = this.move_dir.x() * target_dir.y() - this.move_dir.y() * target_dir.x();

                const angle = std.math.atan2(cross, dot);

                this.walk.update(g.dt, .init(1, 0));

                this.lean.update(g.dt, .init(0.15, angle));
            } else {
                this.walk.update(g.dt, .init(0, 0));
                this.lean.update(g.dt, .init(-this.pos.velocity.len() * 0.1, 0));
            }
            this.walk_angle += this.pos.velocity.len() / 300 * g.dt;
            this.dir.update(g.dt, this.move_dir);
            this.dir.value = this.dir.value.normalize(0.1);

            const angle: m.Mat4x4 = .rotateY(std.math.atan2(-this.dir.value.y(), this.dir.value.x()) + std.math.pi / 2.0);
            const lean = m.Mat4x4.rotateZ(this.lean.value.y()).mul(.rotateX(this.lean.value.x()));

            const jump = @abs(@cos(this.walk_angle)) * this.walk.value.x() / 2;

            const gait = m.Mat4x4.translate(.init(0, jump, 0));

            const basemodel = m.Mat4x4.translate(this.pos.value).mul(angle).mul(lean).mul(gait);

            // try g.ctx.icosphere_3.add(gpa, basemodel.mul(.scale(.init(0.2, 0.2, 0.2))), .init(0, 0, 1, 1));

            {
                const scale: m.Mat4x4 = .scale(.init(0.3, 0.4, 0.4));
                const pos: m.Mat4x4 = .translate(.init(0, 1, 0));

                try g.ctx.head.add(gpa, basemodel.mul(pos).mul(scale), color);
            }

            {
                const scale: m.Mat4x4 = .scale(.init(0.35, 0.35, 0.35));
                const transl: m.Mat4x4 = .translate(.init(0, 0.5, 0));

                try g.ctx.cylinder.add(gpa, basemodel.mul(transl).mul(scale), color);
            }
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

            var lstick: m.Vec2 = .init(0, 0);
            if (this.input.a) lstick.v[0] -= 1;
            if (this.input.d) lstick.v[0] += 1;
            if (this.input.w) lstick.v[1] -= 1;
            if (this.input.s) lstick.v[1] += 1;

            const len = @max(lstick.len(), 1);

            avatar.inputs.lstick = lstick.divScalar(len);

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
