const std = @import("std");

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;

const Canvas = @import("../js/pixel.zig").Canvas;

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
            const bdist = (block.box.y_top() + block.box.vel[1]) - (this.y_bottom() + this.vel[1]);
            const tdist = (this.y_top() + this.vel[1]) - (block.box.y_bottom() + block.box.vel[1]);
            const rdist = (block.box.x_left() + block.box.vel[0]) - (this.x_right() + this.vel[0]);
            const ldist = (this.x_left() + this.vel[0]) - (block.box.x_right() + block.box.vel[0]);

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

    pub fn render(this: Box, z: f32, color: RGBA) void {
        Canvas.boxf(this.x_left(), this.y_top(), this.size[0], this.size[1], z, color);
    }
};

pub const Block = struct {
    id: usize,
    box: Box,

    pub fn render(this: *Block) void {
        this.box.render(5, comptime RGBA.fromHex("#666666"));
    }
};

pub const Level = struct {
    blocks: lib.Container(Block, 16),

    pub fn render(this: *Level) void {
        for (this.blocks.items[0..this.blocks.len]) |*block| {
            block.render();
        }
    }

    pub fn init() !Level {
        var level = Level{
            .blocks = lib.Container(Block, 16).init(),
        };

        const blocksInit = [_]struct { f32, f32, f32, f32 }{
            .{ 0, -40, 300, 10 },
            .{ -30, -20, 40, 10 },
            .{ -60, 0, 40, 10 },
            .{ 0, 20, 100, 10 },
            .{ -30, 30, 200, 10 },
            .{ -40, 40, 300, 10 },
        };

        for (blocksInit) |vals| {
            const block = try level.blocks.addOne();
            block.*.box = game.Box.init(.{ vals[0], vals[1] }, .{ vals[2], vals[3] });
        }

        return level;
    }
};
