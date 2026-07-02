const std = @import("std");
const debug = @import("./debug.zig");

extern fn js_flush_canvas() void;

const wal = std.heap.wasm_allocator;

const v2 = @import("../lib/root.zig").v2;
const v3 = @import("../lib/root.zig").v3;

const lib = @import("../lib/root.zig");
const RGBA = @import("../lib/root.zig").RGBA;

const MAX_LIGHTS = 8;

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
            this.clear();
        }

        pub fn clear(this: *This) void {
            @memset(this.data, std.mem.zeroes(T));
        }

        pub fn deinit(this: *This, allocator: std.mem.Allocator) void {
            allocator.free(this.data);
        }
    };
}

// pub fn index(this: *This, x: usize, y: usize) usize {
//     return x + this.width * y;
// }

// pub fn get(this: *This, x: usize, y: usize) T {
//     return this.get(x, y);
// }

// pub fn row(this: *This, y: usize) []T {
//     return this.data[this.index(0, y)..this.index(0, y + 1)];
// }
const Light = extern struct {
    mode: i32,
    intensity: f32,
    spot_cutoff_rads: f32,
    pos: [3]f32,
    target: [3]f32,
    color: [3]f32,
};

pub var image: Texture2D(RGBA) = .empty;

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
    image.data[i] = color;
}
pub fn begin() void {
    const width: usize = @intCast(camera.size[0]);
    const height: usize = @intCast(camera.size[1]);
    if (width != image.width or height != image.height) {
        image.resize(std.heap.wasm_allocator, width, height) catch |e| debug.fail(e);
    } else {
        image.clear();
    }
}

pub fn flush() void {
    js_flush_canvas();
}

pub const Canvas = struct {
    pub fn pixel(px: i32, py: i32, z: f32, color: RGBA) void {
        _ = px;
        _ = py;
        _ = z;
        _ = color;
    }
    pub fn box(x: anytype, y: anytype, w: anytype, h: anytype, z: f32, color: RGBA) void {
        const x0: i32 = @intCast(x);
        const y0: i32 = @intCast(y);
        const x1: i32 = @intCast(x + w);
        const y1: i32 = @intCast(y + h);

        var py = y0;
        while (py < y1) : (py += 1) {
            var px = x0;
            while (px < x1) : (px += 1) {
                Canvas.pixel(px, py, z, color);
            }
        }
    }
    pub fn boxf(x: f32, y: f32, w: f32, h: f32, z: f32, color: RGBA) void {
        const x0: i32 = @trunc(x);
        const y0: i32 = @trunc(y);
        const x1: i32 = @trunc(x + w);
        const y1: i32 = @trunc(y + h);

        var py = y0;
        while (py < y1) : (py += 1) {
            var px = x0;
            while (px < x1) : (px += 1) {
                Canvas.pixel(px, py, z, color);
            }
        }
    }

    pub fn light_point(pos: v3.Value, color: RGBA, intensity: f32) void {
        _ = pos;
        _ = color;
        _ = intensity;
    }

    pub fn light_directional(direction: v3.Value, color: RGBA, intensity: f32) void {
        _ = direction;
        _ = color;
        _ = intensity;
    }

    pub fn render_x0() i32 {
        return 0;
    }
    pub fn render_x1() i32 {
        return 1;
    }
    pub fn render_y0() i32 {
        return 0;
    }
    pub fn render_y1() i32 {
        return 1;
    }
    pub fn render_width() i32 {
        return 1;
    }
    pub fn render_height() i32 {
        return 1;
    }
};
