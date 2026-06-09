extern fn jsLogf32(n: f64) void;
extern fn jsLogu8(n: u8) void;

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

const DrawCommand = union(enum) {
    clearRect: struct { x: u32, y: u32, width: u32, height: u32 },
    fillRect: struct { x: u32, y: u32, width: u32, height: u32 },
};

const DrawCommands = struct {
    length: u32,
    commands: [8]DrawCommand,
};

var output: DrawCommands = undefined;
export fn getOutputPtr() *DrawCommands {
    return &output;
}
export fn getOutputLen() usize {
    return @sizeOf(@TypeOf(output));
}
export fn getDrawCommandLen() usize {
    return @sizeOf(DrawCommand);
}

export fn main() void {}

export fn frame(time: f64, screenWidth: u32, screenHeight: u32) void {
    // jsLogf32(time);
    _ = time;
    _ = screenHeight;
    _ = screenWidth;

    output.commands[output.length] = DrawCommand{
        .clearRect = .{
            .x = 1,
            .y = 2,
            .width = 3,
            .height = 4,
        },
    };
    output.length += 1;

    output.commands[output.length] = DrawCommand{
        .fillRect = .{
            .x = 5,
            .y = 6,
            .width = 7,
            .height = 8,
        },
    };
    output.length += 1;
}
