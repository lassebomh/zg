const std = @import("std");

const debug = @import("../js/debug.zig");
const Input = @import("../js/inputs.zig").Input;
const lib = @import("../lib/root.zig");
const m = @import("../math/main.zig");
const vec2 = m.Vec2;
const vec3 = m.Vec3;
const quat = m.Quat;
const mat4 = m.Mat4x4;
const game = @import("./root.zig");

const avatarColors = [_]m.Vec4{
    .init(1.00, 0.15, 0.05, 1),
    .init(0.1, 0.90, 0.10, 1),
    .init(0.20, 0.45, 1.00, 1),
    .init(1.00, 0.7, 0.0, 1),
    .init(0.10, 0.90, 0.90, 1),
    .init(0.95, 0.15, 0.95, 1),
};

pub const Avatar = struct {
    id: usize,
    inputs: struct {
        jump: bool,
        lstick: vec2,
        rstick: vec2,
    },

    position: vec3,

    pub fn create(id: usize) Avatar {
        return Avatar{
            .id = id,
            .inputs = .{
                .jump = false,
                .lstick = .init(0, 0),
                .rstick = .init(0, 0),
            },
            .position = .init(0, 0, 0),
        };
    }

    pub fn update(this: *Avatar, g: *game.State) void {
        _ = g; // autofix

        this.position = this.position.add(vec3.init(this.inputs.lstick.x(), 0, this.inputs.lstick.y()).mulScalar(0.1));
    }

    pub const Render = struct {
        id: usize,

        targetDir: quat = .identity(),
        lookDir: lib.SecondOrderQuat = .init(4, 0.5, 0),
        pos: lib.SecondOrder(vec3) = .init(4, 0.6, 0),

        pub fn init(g: *game.State.Render, avatar: Avatar) Render {
            _ = g; // autofix
            return .{ .id = avatar.id };
        }

        pub fn render(this: *Render, g: *game.State.Render, gpa: std.mem.Allocator) !void {
            const avatar = g.state.avatars.get(this.id).?;

            if (avatar.inputs.lstick.len() > 0.2) {
                this.targetDir = quat.identity().rotateY(-std.math.atan2(avatar.inputs.lstick.y(), avatar.inputs.lstick.x()));
            }

            this.lookDir.update(g.dt, this.targetDir);
            this.pos.update(g.dt, avatar.position);

            const color = avatarColors[avatar.id % avatarColors.len];

            const model = mat4
                .translate(this.pos.value.add(.init(0, 1, 0)))
                .mul(mat4.rotateByQuaternion(this.lookDir.value))
                .mul(mat4.scale(.init(0.75, 1, 0.75)));

            try g.ctx.cylinder.add(gpa, model, color);
        }
    };
};

pub const Player = struct {
    id: usize,
    peer_id: i32,
    avatar_id: ?usize,
    input: Input,

    pub fn upsert_avatar(this: *Player, g: *game.State) *Avatar {
        const avatar_id = this.avatar_id orelse init: {
            const avatar = g.avatars.addOne() catch |e| debug.fail(e);
            avatar.* = Avatar.create(avatar.id);
            this.avatar_id = avatar.id;
            break :init avatar.id;
        };

        return g.avatars.get(avatar_id).?;
    }

    pub fn update(this: *Player, g: *game.State) void {
        if (this.input.space or this.avatar_id != null) {
            var avatar = this.upsert_avatar(g);

            var lstick: vec2 = .init(0, 0);
            if (this.input.a) lstick.v[0] -= 1;
            if (this.input.d) lstick.v[0] += 1;
            if (this.input.w) lstick.v[1] -= 1;
            if (this.input.s) lstick.v[1] += 1;

            const len = @max(lstick.len(), 1);

            avatar.inputs.lstick = lstick.divScalar(len);
            avatar.inputs.jump = this.input.space;
        }
    }
};
