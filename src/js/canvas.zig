const std = @import("std");

const RGBA = @import("../lib/root.zig").RGBA;

extern fn jsFlushCommands(commandsTypesPtr: *[commandsCap]CommandType, commandsArgsPtr: *[commandsCap][7]f32, commandsLen: u8) void;

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

const commandsCap = 255;

var commandsLen: u8 = 0;
var commandsArgs: [commandsCap][7]f32 = undefined;
var commandsTypes: [commandsCap]CommandType = undefined;

pub fn flush() void {
    if (commandsLen == 0) return;
    jsFlushCommands(&commandsTypes, &commandsArgs, commandsLen);
    commandsLen = 0;
    commandsArgs = std.mem.zeroes(@TypeOf(commandsArgs));
    commandsTypes = std.mem.zeroes(@TypeOf(commandsTypes));
}

fn next() u32 {
    var i = commandsLen;
    commandsLen = std.math.add(@TypeOf(commandsLen), commandsLen, 1) catch {
        flush();
        i = 0;
        return 0;
    };
    return i;
}

pub fn save() void {
    commandsTypes[next()] = CommandType.save;
}
pub fn restore() void {
    commandsTypes[next()] = CommandType.restore;
}

pub fn beginPath() void {
    commandsTypes[next()] = CommandType.beginPath;
}

pub fn moveTo(position: @Vector(2, f32)) void {
    const i = next();
    commandsTypes[i] = CommandType.moveTo;
    commandsArgs[i][0] = position[0];
    commandsArgs[i][1] = position[1];
}
pub fn lineTo(position: @Vector(2, f32)) void {
    const i = next();
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
    const i = next();
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
    const i = next();
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
    const i = next();
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
    const i = next();
    commandsTypes[i] = CommandType.bezierCurveTo;
    commandsArgs[i][0] = control1[0];
    commandsArgs[i][1] = control1[1];
    commandsArgs[i][2] = control2[0];
    commandsArgs[i][3] = control2[1];
    commandsArgs[i][4] = point[0];
    commandsArgs[i][5] = point[1];
}

pub fn stroke() void {
    commandsTypes[next()] = CommandType.stroke;
}
pub fn fill() void {
    commandsTypes[next()] = CommandType.fill;
}

pub fn fillRect(position: @Vector(2, f32), size: @Vector(2, f32)) void {
    const i = next();
    commandsTypes[i] = CommandType.fillRect;
    commandsArgs[i][0] = position[0];
    commandsArgs[i][1] = position[1];
    commandsArgs[i][2] = size[0];
    commandsArgs[i][3] = size[1];
}
pub fn strokeRect(position: @Vector(2, f32), size: @Vector(2, f32)) void {
    const i = next();
    commandsTypes[i] = CommandType.strokeRect;
    commandsArgs[i][0] = position[0];
    commandsArgs[i][1] = position[1];
    commandsArgs[i][2] = size[0];
    commandsArgs[i][3] = size[1];
}
pub fn clearRect(position: @Vector(2, f32), size: @Vector(2, f32)) void {
    const i = next();
    commandsTypes[i] = CommandType.clearRect;
    commandsArgs[i][0] = position[0];
    commandsArgs[i][1] = position[1];
    commandsArgs[i][2] = size[0];
    commandsArgs[i][3] = size[1];
}

pub fn translate(vector: @Vector(2, f32)) void {
    const i = next();
    commandsTypes[i] = CommandType.translate;
    commandsArgs[i][0] = vector[0];
    commandsArgs[i][1] = vector[1];
}
pub fn scale(vector: @Vector(2, f32)) void {
    const i = next();
    commandsTypes[i] = CommandType.scale;
    commandsArgs[i][0] = vector[0];
    commandsArgs[i][1] = vector[1];
}
pub fn rotate(angle: f32) void {
    const i = next();
    commandsTypes[i] = CommandType.rotate;
    commandsArgs[i][0] = angle;
}

pub fn lineWidth(px: f32) void {
    const i = next();
    commandsTypes[i] = CommandType.lineWidth;
    commandsArgs[i][0] = px;
}

pub fn fillStyle(color: RGBA) void {
    const i = next();
    commandsTypes[i] = CommandType.fillStyle;
    var args = &commandsArgs[i];
    args[0] = @floatFromInt(color.r);
    args[1] = @floatFromInt(color.g);
    args[2] = @floatFromInt(color.b);
    args[3] = @as(f32, @floatFromInt(color.alpha)) / 255;
}
pub fn strokeStyle(color: RGBA) void {
    const i = next();
    commandsTypes[i] = CommandType.strokeStyle;
    var args = &commandsArgs[i];
    args[0] = @floatFromInt(color.r);
    args[1] = @floatFromInt(color.g);
    args[2] = @floatFromInt(color.b);
    args[3] = @as(f32, @floatFromInt(color.alpha)) / 255;
}
pub fn shadowColor(color: RGBA) void {
    const i = next();
    commandsTypes[i] = CommandType.shadowColor;
    var args = &commandsArgs[i];
    args[0] = @floatFromInt(color.r);
    args[1] = @floatFromInt(color.g);
    args[2] = @floatFromInt(color.b);
    args[3] = @as(f32, @floatFromInt(color.alpha)) / 255;
}
