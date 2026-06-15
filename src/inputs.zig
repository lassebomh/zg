pub var inputs: Inputs = .{
    .w = 0,
    .a = 0,
    .s = 0,
    .d = 0,
    .space = 0,
    .shift = 0,
    .mouse = .{ 0, 0 },
    .mouse_left = 0,
    .mouse_right = 0,
    .screen = .{ 0, 0 },
};

export fn getInputsPtr() *Inputs {
    return &inputs;
}

pub const Inputs = extern struct {
    w: f32,
    a: f32,
    s: f32,
    d: f32,
    space: f32,
    shift: f32,
    mouse: @Vector(2, f32),
    mouse_left: f32,
    mouse_right: f32,
    screen: @Vector(2, f32),
};
