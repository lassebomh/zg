const std = @import("std");
const js = @import("../js/root.zig");

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;

pub const Directions = packed struct {
    tl: bool,
    tc: bool,
    tr: bool,
    cr: bool,
    br: bool,
    bc: bool,
    bl: bool,
    cl: bool,
};

pub const Box = struct {
    position: v2.Value,
    size: v2.Value,
    vel: v2.Value,
    impact: v2.Value,

    pub fn init(pos: v2.Value, size: v2.Value) Box {
        return Box{
            .position = pos,
            .size = size,
            .vel = v2.zero,
            .impact = v2.zero,
        };
    }

    pub fn x_left(this: Box) f32 {
        return this.position[0] - this.size[0] / 2;
    }
    pub fn x_right(this: Box) f32 {
        return this.position[0] + this.size[0] / 2;
    }
    pub fn x_center(this: Box) f32 {
        return this.position[0];
    }
    pub fn y_top(this: Box) f32 {
        return this.position[1] - this.size[1] / 2;
    }
    pub fn y_bottom(this: Box) f32 {
        return this.position[1] + this.size[1] / 2;
    }
    pub fn y_center(this: Box) f32 {
        return this.position[1];
    }

    pub fn tl(this: Box) v2.Value {
        return v2.xy(this.x_left(), this.y_top());
    }
    pub fn tc(this: Box) v2.Value {
        return v2.xy(this.x_center(), this.y_top());
    }
    pub fn tr(this: Box) v2.Value {
        return v2.xy(this.x_right(), this.y_top());
    }
    pub fn cr(this: Box) v2.Value {
        return v2.xy(this.x_right(), this.y_center());
    }
    pub fn br(this: Box) v2.Value {
        return v2.xy(this.x_right(), this.y_bottom());
    }
    pub fn bc(this: Box) v2.Value {
        return v2.xy(this.x_center(), this.y_bottom());
    }
    pub fn bl(this: Box) v2.Value {
        return v2.xy(this.x_left(), this.y_bottom());
    }
    pub fn cl(this: Box) v2.Value {
        return v2.xy(this.x_left(), this.y_center());
    }

    pub fn cc(this: Box) v2.Value {
        return this.position;
    }

    pub fn lerp(this: Box, other: Box, alpha: f32) Box {
        const a = v2.fill(alpha);
        return Box{
            .position = v2.lerp(other.position, this.position, a),
            .size = v2.lerp(other.size, this.size, a),
            .vel = v2.lerp(other.vel, this.vel, a),
            .impact = v2.lerp(other.impact, this.impact, a),
        };
    }

    pub fn right_distance_to(this: Box, other: Box) f32 {
        return other.x_left() - this.x_right();
    }

    pub fn left_distance_to(this: Box, other: Box) f32 {
        return this.x_left() - other.x_right();
    }

    pub fn top_distance_to(this: Box, other: Box) f32 {
        return this.y_top() - other.y_bottom();
    }

    pub fn bottom_distance_to(this: Box, other: Box) f32 {
        return other.y_top() - this.y_bottom();
    }

    pub fn update(this: *Box, g: *game.State) void {
        this.impact = v2.zero;

        for (g.level.blocks.items[0..g.level.blocks.len]) |block| {
            const bdist = (block.y_top() + block.vel[1]) - (this.y_bottom() + this.vel[1]);
            const tdist = (this.y_top() + this.vel[1]) - (block.y_bottom() + block.vel[1]);
            const rdist = (block.x_left() + block.vel[0]) - (this.x_right() + this.vel[0]);
            const ldist = (this.x_left() + this.vel[0]) - (block.x_right() + block.vel[0]);

            if (bdist < 0 and ldist < 0 and rdist < 0 and tdist < 0) {
                if (@max(ldist, rdist) > @max(bdist, tdist)) {
                    const dx = if (rdist > ldist) rdist else -ldist;
                    this.vel[0] += dx;
                    this.impact[0] += dx;
                } else {
                    const dy = if (bdist > tdist) bdist else -tdist;
                    this.vel[1] += dy;
                    this.impact[1] += dy;
                }
            }
        }

        this.position += this.vel;
    }

    pub fn render(this: Box, prev: Box, alpha: f32) void {
        const box = this.lerp(prev, alpha);

        js.ctx.save();
        defer js.ctx.restore();

        js.ctx.lineWidth(0.5);
        js.ctx.strokeStyle(RGBA.fromHex("#00ff00"));
        js.ctx.strokeRect(box.tl(), box.size);

        js.ctx.strokeStyle(RGBA.fromHex("#ff00ff"));
        js.ctx.beginPath();
        js.ctx.moveTo(box.cc());
        js.ctx.lineTo(box.cc() + box.impact * v2.fill(1));
        js.ctx.stroke();

        js.ctx.strokeStyle(RGBA.fromHex("#0077ff"));
        js.ctx.beginPath();
        js.ctx.moveTo(box.cc());
        js.ctx.lineTo(box.cc() + box.vel * v2.fill(1));
        js.ctx.stroke();
    }
};

pub const Level = struct {
    blocks: lib.Container(Box, 16),

    pub fn collides(this: *Level, pos: v2.Value) bool {
        _ = this;
        _ = pos;
        return true;
    }

    pub fn render(this: *Level) void {
        js.ctx.fillStyle(RGBA.fromHex("#0000ff"));

        for (this.blocks.items[0..this.blocks.len]) |block| {
            block.render(block, 1);
        }
    }

    pub fn init() Level {
        var level = Level{
            .blocks = lib.Container(Box, 16).init(),
        };

        level.blocks.new().item.* = Box.init(v2.xy(0, -40), v2.xy(300, 10));

        level.blocks.new().item.* = Box.init(v2.xy(0, 20), v2.xy(100, 10));
        level.blocks.new().item.* = Box.init(v2.xy(0, 30), v2.xy(200, 10));
        level.blocks.new().item.* = Box.init(v2.xy(0, 40), v2.xy(300, 10));

        return level;
    }
};

// pub const level0 = .{
//     "###################################",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "#                                 #",
//     "###################################",
// };
// // pub fn parse_level(comptime str: []*const u8) type {}
