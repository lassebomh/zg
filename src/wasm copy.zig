const std = @import("std");
const lib = @import("./lib/root.zig");
const v2 = lib.v2;

const js = @import("./js/root.zig");
const game = @import("./game/root.zig");

const TICK_RATE = 1000.0 / 60.0;

var peersInputs: [js.inputs.MaxPeers]js.inputs.Inputs = undefined;

export fn getInputsPtr() *[js.inputs.MaxPeers]js.inputs.Inputs {
    return &peersInputs;
}

var prev_seen_tick: i32 = 0;
var prev_state: ?game.State = null;

var curr_state: game.State = game.State.init();

export fn onAnimationFrame(time_offset: i32, screen_width: i32, screen_height: i32, peer_id: i32) void {
    const screen: v2.Value = .{
        @floatFromInt(screen_width),
        @floatFromInt(screen_height),
    };

    const ftick: f32 = @as(f32, @floatFromInt(time_offset)) / TICK_RATE;
    const itick: i32 = @trunc(ftick);
    const alpha = ftick - @floor(ftick);

    if (itick != prev_seen_tick) {
        prev_seen_tick = itick;

        prev_state = curr_state;
        curr_state.update(&peersInputs);
        // if (itick == 100) {
        // log("{}", .{inputs.inputs.mouse});
        // }
    }

    curr_state.render(&(prev_state orelse curr_state), alpha, screen, peer_id);
}

export fn main() void {
    // js.debug.log("{}", .{@sizeOf(game.State)});
}
