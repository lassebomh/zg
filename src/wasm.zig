const std = @import("std");

extern fn jsLogf32(n: f32) void;
extern fn jsLogu64(n: u64) void;
extern fn jsLogu32(n: u32) void;

pub const MyStruct = struct {
    bar: f32,
    foo: u8,
};

var data: MyStruct = .{
    .foo = 0,
    .bar = 1.123123,
};
export fn getInputPtr() *MyStruct {
    return &data;
}
export fn getInputLen() usize {
    return @sizeOf(@TypeOf(data));
}

const Rect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

const RGBA = extern struct {
    r: u32,
    g: u32,
    b: u32,
    alpha: u32,

    fn fromHex(comptime hex: []const u8) RGBA {
        const rgba = RGBA{
            .r = std.fmt.parseUnsigned(u32, hex[1..3], 16) catch unreachable,
            .g = std.fmt.parseUnsigned(u32, hex[3..5], 16) catch unreachable,
            .b = std.fmt.parseUnsigned(u32, hex[5..7], 16) catch unreachable,
            .alpha = 255,
        };
        if (hex.len == 8) {
            rgba.alpha = std.fmt.parseUnsigned(u32, hex[7..9], 16) catch unreachable;
        }
        return rgba;
    }
};

const DrawCommand = extern struct {
    tag: enum(u32) {
        clearRect,
        fillRect,
        setFillStyle,
    },
    payload: extern union {
        clearRect: Rect,
        fillRect: Rect,
        setFillStyle: RGBA,
    },
};
const DrawCommands = struct {
    length: u32,
    items: [8]DrawCommand,
};
var output: DrawCommands = undefined;
export fn getOutputPtr() *DrawCommands {
    return &output;
}

const Vec2 = @Vector(2, f32);

export fn main() void {}

export fn frame(timeOffset: u32, screenWidth: u32, screenHeight: u32) void {
    // const canvas:

    const w: f32 = @floatFromInt(screenWidth);
    const h: f32 = @floatFromInt(screenHeight);

    output = std.mem.zeroInit(DrawCommands, .{});

    output.items[output.length] = DrawCommand{
        .tag = .clearRect,
        .payload = .{ .clearRect = .{
            .x = 0,
            .y = 0,
            .width = w,
            .height = h,
        } },
    };
    output.length += 1;

    output.items[output.length] = DrawCommand{
        .tag = .setFillStyle,
        .payload = .{
            .setFillStyle = RGBA.fromHex("#e69d9d"),
        },
    };
    output.length += 1;

    const t: f32 = @as(f32, @floatFromInt(timeOffset)) / 1000.0;

    const offset_x: f32 = std.math.sin(t) * 100.0;
    const offset_y: f32 = std.math.cos(t) * 100.0;

    const canvas: Vec2 = .{
        w,
        h,
    };

    const offset: Vec2 = .{
        offset_x,
        offset_y,
    };

    const pos = canvas / @as(Vec2, @splat(4)) + offset;

    output.items[output.length] = DrawCommand{
        .tag = .fillRect,
        .payload = .{ .fillRect = .{
            .x = pos[0],
            .y = pos[1],
            .width = w / 2,
            .height = h / 2,
        } },
    };
    output.length += 1;
}
