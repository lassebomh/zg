pub const MaxPeers = 16;

pub const Inputs = extern struct {
    peer_id: i32,
    w: bool,
    a: bool,
    s: bool,
    d: bool,
    space: bool,
    shift: bool,
    mouse_x: f32,
    mouse_y: f32,
    mouse_left: bool,
    mouse_right: bool,
    screen_width: f32,
    screen_height: f32,
};
