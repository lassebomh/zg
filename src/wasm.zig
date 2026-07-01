const std = @import("std");
const debug = @import("./js/debug.zig");

extern fn js_flush_canvas() void;

const wal = std.heap.wasm_allocator;

const v2 = @import("lib/root.zig").v2;
const v3 = @import("lib/root.zig").v3;

const RGBA = extern struct {
    r: u8,
    g: u8,
    b: u8,
    alpha: u8,

    pub fn fromHex(hex: []const u8) RGBA {
        var rgba = RGBA{
            .r = std.fmt.parseUnsigned(u8, hex[1..3], 16) catch unreachable,
            .g = std.fmt.parseUnsigned(u8, hex[3..5], 16) catch unreachable,
            .b = std.fmt.parseUnsigned(u8, hex[5..7], 16) catch unreachable,
            .alpha = 255,
        };
        if (hex.len == 9) {
            rgba.alpha = std.fmt.parseUnsigned(u8, hex[7..9], 16) catch unreachable;
        }
        return rgba;
    }

    pub fn fromHSL(degrees: f32, s: f32, l: f32) RGBA {
        const h = @mod(degrees, 360.0);
        const c = (1.0 - @abs(2.0 * l - 1.0)) * s;
        const hp = h / 60.0;
        const x = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
        const m = l - c / 2.0;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (hp < 1) {
            r = c;
            g = x;
        } else if (hp < 2) {
            r = x;
            g = c;
        } else if (hp < 3) {
            g = c;
            b = x;
        } else if (hp < 4) {
            g = x;
            b = c;
        } else if (hp < 5) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }

        return RGBA{
            .r = @intFromFloat((r + m) * 255.0),
            .g = @intFromFloat((g + m) * 255.0),
            .b = @intFromFloat((b + m) * 255.0),
            .alpha = 255,
        };
    }
};

const MAX_LIGHTS = 8;

const Light = extern struct {
    mode: i32,
    intensity: f32,
    spot_cutoff_rads: f32,
    __1: f32 = 0,
    pos: [3]f32,
    __2: f32 = 0,
    target: [3]f32,
    __3: f32 = 0,
    color: [3]f32,
    __4: f32 = 0,
};

const UBO = extern struct {
    render_width: i32,
    render_height: i32,
    render_x: i32,
    render_y: i32,

    light_width: i32,
    light_height: i32,
    light_x: i32,
    light_y: i32,

    light_dx: i32,
    light_dy: i32,

    screen_width: f32,
    screen_height: f32,

    screen_x: f32,
    screen_y: f32,

    lights_len: i32,
    frame: i32 = 0,

    lights: [MAX_LIGHTS]Light,
};

var color_data: []RGBA = wal.alloc(RGBA, 0) catch |e| debug.fail(e);
var height_data: []f32 = wal.alloc(f32, 0) catch |e| debug.fail(e);

var ubo: UBO = .{
    .lights = undefined,
    .lights_len = 0,

    .render_width = 300,
    .render_height = 200,
    .render_x = 0,
    .render_y = 0,

    .light_width = 250,
    .light_height = 150,
    .light_x = 0,
    .light_y = 0,
    .light_dx = 0,
    .light_dy = 0,

    .screen_width = 225,
    .screen_height = 125,
    .screen_x = 0,
    .screen_y = 0,
};

export fn js_get_color_tex_offset() [*]RGBA {
    return color_data.ptr;
}
export fn js_get_color_tex_len() usize {
    return color_data.len;
}
export fn js_get_height_tex_offset() [*]f32 {
    return height_data.ptr;
}
export fn js_get_height_tex_len() usize {
    return height_data.len;
}

export fn js_get_ubo_offset() *UBO {
    return &ubo;
}
export fn js_get_ubo_size() usize {
    return @sizeOf(UBO);
}

var t: f32 = 0;

const Canvas = struct {
    pub fn pixel(px: i32, py: i32, z: f32, color: RGBA) void {
        const x = px - ubo.render_x;
        const y = py - ubo.render_y;
        if (x < 0 or y < 0 or x >= ubo.render_width or y >= ubo.render_height) return;
        const i: usize = @intCast(y * ubo.render_width + x);
        const current_height = height_data[i];
        if (z < current_height) return;
        color_data[i] = color;
        height_data[i] = z;
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

    pub fn light_point(pos: v3.Value, color: RGBA, intensity: f32) void {
        if (ubo.lights_len >= MAX_LIGHTS) return;

        const i = ubo.lights_len;

        var r: f32 = @floatFromInt(color.r);
        r /= 255;

        var g: f32 = @floatFromInt(color.g);
        g /= 255;

        var b: f32 = @floatFromInt(color.b);
        b /= 255;

        // var alpha: f32 = @floatFromInt(color.alpha);
        // alpha /= 255;

        ubo.lights[@intCast(i)] = Light{
            .color = .{ r, g, b },
            .intensity = intensity,
            .pos = pos,
            .mode = 1,
            .spot_cutoff_rads = 0,
            .target = .{ 0, 0, 0 },
        };
        ubo.lights_len += 1;
    }

    pub fn begin(camera_pos: v2.Value, camera_size: v2.Value) void {
        t += 1;
        ubo.frame = @intFromFloat(t);
        ubo.screen_x = camera_pos[0] - camera_size[0] / 2;
        ubo.screen_y = camera_pos[1] - camera_size[1] / 2;
        ubo.screen_width = camera_size[0];
        ubo.screen_height = camera_size[1];

        const center: @Vector(2, i32) = @trunc(camera_pos);

        const prev_light_x = ubo.light_x;
        const prev_light_y = ubo.light_y;
        ubo.light_width = @trunc(camera_size[0] + 20);
        ubo.light_height = @trunc(camera_size[1] + 20);
        ubo.light_x = center[0] - @divTrunc(ubo.light_width, 2);
        ubo.light_y = center[1] - @divTrunc(ubo.light_height, 2);
        ubo.light_dx = ubo.light_x - prev_light_x;
        ubo.light_dy = ubo.light_y - prev_light_y;

        const prev_render_width = ubo.render_width;
        const prev_render_height = ubo.render_height;
        ubo.render_width = ubo.light_width + 20;
        ubo.render_height = ubo.light_height + 20;
        ubo.render_x = center[0] - @divTrunc(ubo.render_width, 2);
        ubo.render_y = center[1] - @divTrunc(ubo.render_height, 2);

        if (prev_render_width != ubo.render_width or prev_render_height != ubo.render_height) {
            wal.free(color_data);
            color_data = wal.alloc(RGBA, @intCast(ubo.render_width * ubo.render_height)) catch |e| debug.fail(e);

            wal.free(height_data);
            height_data = wal.alloc(f32, @intCast(ubo.render_width * ubo.render_height)) catch |e| debug.fail(e);
        } else {
            for (0..color_data.len) |i| {
                color_data[i] = RGBA{ .r = 0, .g = 0, .b = 0, .alpha = 0 };
                height_data[i] = 0;
            }
        }

        ubo.lights = undefined;
        ubo.lights_len = 0;
    }

    pub fn flush() void {
        js_flush_canvas();
    }

    pub fn render_x0() i32 {
        return ubo.render_x;
    }
    pub fn render_x1() i32 {
        return ubo.render_x + ubo.render_width;
    }
    pub fn render_y0() i32 {
        return ubo.render_y;
    }
    pub fn render_y1() i32 {
        return ubo.render_y + ubo.render_height;
    }
    pub fn render_width() i32 {
        return ubo.render_width;
    }
    pub fn render_height() i32 {
        return ubo.render_height;
    }
};

export fn js_render(new_width: i32, new_height: i32) void {
    Canvas.begin(.{ 0, 0 }, .{ @as(f32, @floatFromInt(new_width)), @floatFromInt(new_height) });
    defer Canvas.flush();

    Canvas.box(0, 0, 10, 10, 2, comptime RGBA.fromHex("#ff0000"));
    // Canvas.box(3, 5, 7, 10, 1, comptime RGBA.fromHex("#ff0000"));
    Canvas.light_point(.{ -20, 0, 10 }, comptime RGBA.fromHex("#ffffff"), 5);

    Canvas.box(Canvas.render_x0(), Canvas.render_y0(), Canvas.render_width(), Canvas.render_height(), 1, comptime RGBA.fromHex("#ffffff"));
}
