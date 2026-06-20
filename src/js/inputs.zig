pub const MaxPeers = 16;

pub const Inputs = extern struct {
    peer_id: i32,
    w: bool,
    a: bool,
    s: bool,
    d: bool,
    space: bool,
    shift: bool,
    mouse: @Vector(2, f32),
    mouse_left: bool,
    mouse_right: bool,
    screen: @Vector(2, f32),
};
