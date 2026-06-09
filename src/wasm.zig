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

const DrawCommand = extern struct { tag: enum(u32) {
    clearRect,
    fillRect,
}, payload: extern union {
    clearRect: extern struct { x: u32, y: u32, width: u32, height: u32 },
    fillRect: extern struct { x: u32, y: u32, width: u32, height: u32 },
} };
const DrawCommands = struct {
    length: u32,
    items: [8]DrawCommand,
};
var output: DrawCommands = undefined;
export fn getOutputPtr() *DrawCommands {
    return &output;
}

export fn main() void {}

export fn frame(time: f32, screenWidth: u32, screenHeight: u32) void {
    jsLogf32(time);
    // jsLogf32(screenWidth);
    // jsLogf32(screenHeight);
    // _ = time;
    // _ = screenHeight;
    // _ = screenWidth;

    output = std.mem.zeroInit(DrawCommands, .{});

    output.items[output.length] = DrawCommand{
        .tag = .clearRect,
        .payload = .{ .clearRect = .{
            .x = 1,
            .y = 2,
            .width = 3,
            .height = 4,
        } },
    };
    output.length += 1;

    output.items[output.length] = DrawCommand{
        .tag = .fillRect,
        .payload = .{ .fillRect = .{
            .x = 5,
            .y = 6,
            .width = screenWidth / 2,
            .height = screenHeight / 2,
        } },
    };
    output.length += 1;
}
