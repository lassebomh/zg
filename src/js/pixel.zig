const std = @import("std");
const debug = @import("./debug.zig");

extern fn js_flush_canvas() void;

const wal = std.heap.wasm_allocator;

const v2 = @import("../lib/root.zig").v2;
const v3 = @import("../lib/root.zig").v3;

const lib = @import("../lib/root.zig");
const RGBA = @import("../lib/root.zig").RGBA;

fn Texture2D(T: type) type {
    return struct {
        const This = @This();

        data: []T = undefined,

        width: usize,
        height: usize,

        pub const empty: This = .{
            .width = 0,
            .height = 0,
            .data = &.{},
        };

        pub fn resize(this: *This, allocator: std.mem.Allocator, new_width: usize, new_height: usize) !void {
            allocator.free(this.data);
            this.width = new_width;
            this.height = new_height;
            this.data = try allocator.alloc(T, this.width * this.height);
        }

        pub fn clear(this: *This) void {
            @memset(this.data, std.mem.zeroes(T));
        }

        pub fn deinit(this: *This, allocator: std.mem.Allocator) void {
            allocator.free(this.data);
        }
    };
}

const Light = union(enum) {
    point: struct {
        pos: @Vector(3, f32),
        color: RGBA,
        intensity: f32,
    },
    directional: struct {
        dir: @Vector(3, f32),
        color: RGBA,
        intensity: f32,
    },
    spot: struct {
        pos: @Vector(3, f32),
        target: @Vector(3, f32),
        // Maximum angle of light dispersion from its direction whose upper bound is Math.PI/2.
        angle: f32,
        // Percent of the spotlight cone that is attenuated due to penumbra. Value range is [0,1].
        penumbra: f32,
        color: RGBA,
        intensity: f32,
    },
};

var lights: std.ArrayList(Light) = .empty;

pub var image: Texture2D(RGBA) = .empty;

pub var colors: Texture2D(RGBA) = .empty;
pub var heights: Texture2D(f32) = .empty;
pub var normals: Texture2D(@Vector(3, f32)) = .empty;

export fn js_get_image_ptr() [*]RGBA {
    return image.data.ptr;
}
export fn js_get_image_width() usize {
    return image.width;
}
export fn js_get_image_height() usize {
    return image.height;
}

pub var camera: *lib.Box(i32) = undefined;

pub fn put(pos: @Vector(2, i32), color: RGBA) void {
    const rel = pos - camera.pos;
    if (rel[0] < 0 or rel[0] >= camera.size[0] or rel[1] < 0 or rel[1] >= camera.size[1]) {
        return;
    }
    const i: usize = @intCast(rel[0] + rel[1] * camera.size[0]);
    colors.data[i] = color;
    heights.data[i] = 1;
    normals.data[i] = .{ 0, 0, 1 };
}

pub fn add_light(light: Light) void {
    const new_light = (&lights).addOne(wal) catch |e| debug.fail(e);
    new_light.* = light;
}

pub fn begin() void {
    const width: usize = @intCast(camera.size[0]);
    const height: usize = @intCast(camera.size[1]);
    if (width != image.width or height != image.height) {
        image.resize(wal, width, height) catch |e| debug.fail(e);
        colors.resize(wal, width, height) catch |e| debug.fail(e);
        heights.resize(wal, width, height) catch |e| debug.fail(e);
        normals.resize(wal, width, height) catch |e| debug.fail(e);
    } else {
        image.clear();
        colors.clear();
        heights.clear();
        normals.clear();
    }
    lights.clearRetainingCapacity();
}
pub fn dot3(a: @Vector(3, f32), b: @Vector(3, f32)) f32 {
    return @reduce(.Add, a * b);
}

pub fn normalize3(v: @Vector(3, f32)) @Vector(3, f32) {
    const len = @sqrt(dot3(v, v));
    if (len < 0.0001) return .{ 0, 0, 0 };
    return v / @as(@Vector(3, f32), @splat(len));
}
pub fn flush() void {
    var iter = camera.iter();

    for (0..image.data.len) |i| {
        const base_color = colors.data[i];
        const pos = (&iter).next().?;
        const pos3d: @Vector(3, f32) = .{
            @floatFromInt(pos[0]),
            @floatFromInt(pos[1]),
            heights.data[i],
        };
        const normal = normals.data[i];

        var total_r: f32 = 0;
        var total_g: f32 = 0;
        var total_b: f32 = 0;

        for (lights.items) |light| {
            var light_dir: @Vector(3, f32) = undefined;
            var attenuation: f32 = 1.0;
            var light_color: RGBA = undefined;
            var intensity: f32 = undefined;

            switch (light) {
                .point => |p| {
                    const diff = p.pos - pos3d;
                    const dist_sq = dot3(diff, diff);
                    const dist = @sqrt(dist_sq);
                    if (dist < 0.0001) {
                        light_dir = .{ 0, 0, 1 };
                    } else {
                        light_dir = diff / @as(@Vector(3, f32), @splat(dist));
                    }
                    attenuation = 1.0 / (1.0 + dist_sq);
                    light_color = p.color;
                    intensity = p.intensity;
                },
                .directional => |d| {
                    light_dir = normalize3(d.dir * @as(@Vector(3, f32), @splat(-1)));
                    attenuation = 1.0;
                    light_color = d.color;
                    intensity = d.intensity;
                },
                .spot => |s| {
                    const diff = s.pos - pos3d;
                    const dist_sq = dot3(diff, diff);
                    const dist = @sqrt(dist_sq);
                    if (dist < 0.0001) {
                        light_dir = .{ 0, 0, 1 };
                    } else {
                        light_dir = diff / @as(@Vector(3, f32), @splat(dist));
                    }
                    const spot_dir = normalize3(s.target - s.pos);
                    const cos_angle = dot3(spot_dir, light_dir * @as(@Vector(3, f32), @splat(-1)));
                    const cos_outer = @cos(s.angle);
                    const cos_inner = @cos(s.angle * (1.0 - s.penumbra));
                    if (cos_angle < cos_outer) {
                        continue;
                    }
                    const spot_effect = std.math.clamp((cos_angle - cos_outer) / @max(cos_inner - cos_outer, 0.0001), 0.0, 1.0);
                    attenuation = spot_effect / (1.0 + dist_sq);
                    light_color = s.color;
                    intensity = s.intensity;
                },
            }

            const ndotl = @max(dot3(normal, light_dir), 0.0);
            const contribution = ndotl * attenuation * intensity;

            total_r += @as(f32, @floatFromInt(light_color.r)) / 255.0 * contribution;
            total_g += @as(f32, @floatFromInt(light_color.g)) / 255.0 * contribution;
            total_b += @as(f32, @floatFromInt(light_color.b)) / 255.0 * contribution;
        }

        image.data[i] = .{
            .r = @intFromFloat(@min(@as(f32, @floatFromInt(base_color.r)) * total_r, 255)),
            .g = @intFromFloat(@min(@as(f32, @floatFromInt(base_color.g)) * total_g, 255)),
            .b = @intFromFloat(@min(@as(f32, @floatFromInt(base_color.b)) * total_b, 255)),
            .alpha = base_color.alpha,
        };
    }

    js_flush_canvas();
}
