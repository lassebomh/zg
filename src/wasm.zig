const std = @import("std");

extern fn jsLogf32(n: f32) void;
extern fn jsLogu64(n: u64) void;
extern fn jsLogu32(n: u32) void;

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
        var rgba = RGBA{
            .r = std.fmt.parseUnsigned(u32, hex[1..3], 16) catch unreachable,
            .g = std.fmt.parseUnsigned(u32, hex[3..5], 16) catch unreachable,
            .b = std.fmt.parseUnsigned(u32, hex[5..7], 16) catch unreachable,
            .alpha = 255,
        };
        if (hex.len == 9) {
            rgba.alpha = std.fmt.parseUnsigned(u32, hex[7..9], 16) catch unreachable;
        }
        return rgba;
    }

    fn fromHSL(degrees: f32, s: f32, l: f32) RGBA {
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

const CommandType = enum(i32) {
    none,

    save,
    restore,

    beginPath,
    moveTo,
    lineTo,
    arc,
    ellipse,
    quadraticCurveTo,
    bezierCurveTo,

    stroke,
    fill,

    fillRect,
    strokeRect,
    clearRect,

    translate,
    scale,
    rotate,

    lineWidth,

    fillStyle,
    strokeStyle,
    shadowColor,
};

const MAX_COMMANDS = 1000;

var commandsArgs: [MAX_COMMANDS][7]f32 = undefined;
var commandsTypes: [MAX_COMMANDS]CommandType = undefined;
var commandsLength: u32 = 0;

export fn getCommandsArgsPtr() *[MAX_COMMANDS][7]f32 {
    return &commandsArgs;
}
export fn getCommandsTypesPtr() *[MAX_COMMANDS]CommandType {
    return &commandsTypes;
}
export fn getCommandsLength() u32 {
    return commandsLength;
}
export fn getMaxCommands() u32 {
    return MAX_COMMANDS;
}

const v2 = struct {
    fn fromRadians(angle: f32) @Vector(2, f32) {
        return .{
            @cos(angle),
            @sin(angle),
        };
    }
    fn fromDegrees(angle: f32) @Vector(2, f32) {
        return .{
            @cos(angle * (std.math.pi / 180.0)),
            @sin(angle * (std.math.pi / 180.0)),
        };
    }

    fn fill(value: f32) @Vector(2, f32) {
        return @splat(value);
    }
};

const ctx = struct {
    pub fn next() u32 {
        const i = commandsLength;
        commandsLength += 1;
        return i;
    }
    pub fn reset() void {
        commandsLength = 0;
        commandsArgs = std.mem.zeroes(@TypeOf(commandsArgs));
        commandsTypes = std.mem.zeroes(@TypeOf(commandsTypes));
    }

    pub fn save() void {
        commandsTypes[ctx.next()] = CommandType.save;
    }
    pub fn restore() void {
        commandsTypes[ctx.next()] = CommandType.restore;
    }

    pub fn beginPath() void {
        commandsTypes[ctx.next()] = CommandType.beginPath;
    }

    pub fn moveTo(position: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.moveTo;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
    }
    pub fn lineTo(position: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.lineTo;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
    }
    pub fn arc(
        position: @Vector(2, f32),
        radius: f32,
        startAngle: f32,
        endAngle: f32,
    ) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.arc;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
        commandsArgs[i][2] = radius;
        commandsArgs[i][3] = startAngle;
        commandsArgs[i][4] = endAngle;
    }
    pub fn ellipse(
        position: @Vector(2, f32),
        radius: @Vector(2, f32),
        rotation: f32,
        startAngle: f32,
        endAngle: f32,
    ) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.ellipse;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
        commandsArgs[i][2] = radius[0];
        commandsArgs[i][3] = radius[1];
        commandsArgs[i][4] = rotation;
        commandsArgs[i][5] = startAngle;
        commandsArgs[i][6] = endAngle;
    }
    pub fn quadraticCurveTo(
        control: @Vector(2, f32),
        point: @Vector(2, f32),
    ) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.quadraticCurveTo;
        commandsArgs[i][0] = control[0];
        commandsArgs[i][1] = control[1];
        commandsArgs[i][2] = point[0];
        commandsArgs[i][3] = point[1];
    }
    pub fn bezierCurveTo(
        control1: @Vector(2, f32),
        control2: @Vector(2, f32),
        point: @Vector(2, f32),
    ) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.bezierCurveTo;
        commandsArgs[i][0] = control1[0];
        commandsArgs[i][1] = control1[1];
        commandsArgs[i][2] = control2[0];
        commandsArgs[i][3] = control2[1];
        commandsArgs[i][4] = point[0];
        commandsArgs[i][5] = point[1];
    }

    pub fn stroke() void {
        commandsTypes[ctx.next()] = CommandType.stroke;
    }
    pub fn fill() void {
        commandsTypes[ctx.next()] = CommandType.fill;
    }

    pub fn fillRect(position: @Vector(2, f32), size: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.fillRect;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
        commandsArgs[i][2] = size[0];
        commandsArgs[i][3] = size[1];
    }
    pub fn strokeRect(position: @Vector(2, f32), size: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.strokeRect;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
        commandsArgs[i][2] = size[0];
        commandsArgs[i][3] = size[1];
    }
    pub fn clearRect(position: @Vector(2, f32), size: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.clearRect;
        commandsArgs[i][0] = position[0];
        commandsArgs[i][1] = position[1];
        commandsArgs[i][2] = size[0];
        commandsArgs[i][3] = size[1];
    }

    pub fn translate(vector: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.translate;
        commandsArgs[i][0] = vector[0];
        commandsArgs[i][1] = vector[1];
    }
    pub fn scale(vector: @Vector(2, f32)) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.scale;
        commandsArgs[i][0] = vector[0];
        commandsArgs[i][1] = vector[1];
    }
    pub fn rotate(angle: f32) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.rotate;
        commandsArgs[i][0] = angle;
    }

    pub fn lineWidth(px: f32) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.lineWidth;
        commandsArgs[i][0] = px;
    }

    pub fn fillStyle(color: RGBA) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.fillStyle;
        var args = &commandsArgs[i];
        args[0] = @floatFromInt(color.r);
        args[1] = @floatFromInt(color.g);
        args[2] = @floatFromInt(color.b);
        args[3] = @as(f32, @floatFromInt(color.alpha)) / 255;
    }
    pub fn strokeStyle(color: RGBA) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.strokeStyle;
        var args = &commandsArgs[i];
        args[0] = @floatFromInt(color.r);
        args[1] = @floatFromInt(color.g);
        args[2] = @floatFromInt(color.b);
        args[3] = @as(f32, @floatFromInt(color.alpha)) / 255;
    }
    pub fn shadowColor(color: RGBA) void {
        const i = ctx.next();
        commandsTypes[i] = CommandType.shadowColor;
        var args = &commandsArgs[i];
        args[0] = @floatFromInt(color.r);
        args[1] = @floatFromInt(color.g);
        args[2] = @floatFromInt(color.b);
        args[3] = @as(f32, @floatFromInt(color.alpha)) / 255;
    }
};

export fn main() void {}

export fn frame(timeOffset: u32, screenWidth: u32, screenHeight: u32) void {
    ctx.reset();

    const screen: @Vector(2, f32) = .{
        @floatFromInt(screenWidth),
        @floatFromInt(screenHeight),
    };
    const t: f32 = @floatFromInt(timeOffset);

    ctx.save();
    defer ctx.restore();

    ctx.strokeStyle(RGBA.fromHSL(t, 1, 0.5));
    ctx.lineWidth(20);
    ctx.beginPath();
    ctx.moveTo(screen / v2.fill(2));
    ctx.lineTo(screen / v2.fill(2) + v2.fromDegrees(t) * v2.fill(@min(screen[0], screen[1]) / 2));
    ctx.stroke();
}
