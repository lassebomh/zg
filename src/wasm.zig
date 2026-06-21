const std = @import("std");
const lib = @import("./lib/root.zig");
const v2 = lib.v2;

const js = @import("./js/root.zig");
const game = @import("./game/root.zig");

const wal = std.heap.wasm_allocator;
const ArrayList = std.ArrayList;

var states: ArrayList(game.State) = .empty;

var peers_inputs: [4]ArrayList(js.inputs.Input) = .{
    .empty, // peer 1
    .empty, // peer 2
    .empty, // peer 3
    .empty, // peer 4
};

var input_buffer: js.inputs.Input = std.mem.zeroes(js.inputs.Input);

export fn jsGetInputBufferPtr() *js.inputs.Input {
    return &input_buffer;
}

export fn jsGetPeerInputsPtr(peer_id: i32) [*]js.inputs.Input {
    return peers_inputs[@intCast(peer_id - 1)].items.ptr;
}
export fn jsGetPeerInputsLen(peer_id: i32) usize {
    return peers_inputs[@intCast(peer_id - 1)].items.len;
}

export fn jsRenderTick(itick: i32, alpha: f32, screen_width: i32, screen_height: i32, peer_id: i32) void {
    const screen: v2.Value = .{
        @floatFromInt(screen_width),
        @floatFromInt(screen_height),
    };

    render(itick, alpha, screen, peer_id) catch |e| js.debug.fail(e);
}

export fn jsPullInputBuffer(itick: i32) void {
    pull_input_buffer(itick) catch |e| js.debug.fail(e);
}

fn render(tick: i32, alpha: f32, screen: v2.Value, peer_id: i32) !void {
    const utick: usize = @intCast(tick);

    // ensure it can hold tick and tick+1
    try states.ensureTotalCapacity(wal, utick + 2);

    // create the genesis state if it doesn't exist
    if (states.items.len == 0) {
        const genesis = try states.addOne(wal);
        genesis.* = game.State.init();
    }

    // ensure all necessary state exist
    while (states.items.len < tick + 2) {
        const new_tick = states.items.len;

        var prev_state_copy = states.items[new_tick - 1];
        var new_state = &prev_state_copy;
        var state_inputs: [4]js.inputs.Input = undefined;

        for (peers_inputs, 0..4, 1..5) |inputs, i, inputs_peer_id| {
            var input = &state_inputs[i];
            if (inputs.items.len == 0) {
                input.peer_id = @intCast(inputs_peer_id);
            } else {
                const inputs_tick: usize = @min(new_tick - 1, inputs.items.len - 1);
                input.* = inputs.items[inputs_tick];
            }
        }

        new_state.update(&state_inputs);

        const new_state_ref = try states.addOne(wal);
        new_state_ref.* = new_state.*;
    }

    const state_left = &states.items[utick];
    const state_right = &states.items[utick + 1];

    state_right.render(state_left, alpha, screen, peer_id);
}

fn pull_input_buffer(itick: i32) !void {
    const tick: usize = @intCast(itick);
    const peer_id = input_buffer.peer_id;
    const peer_index: usize = @intCast(peer_id - 1);
    var peerInputArray = &peers_inputs[peer_index];

    try peerInputArray.ensureTotalCapacity(wal, tick + 1);

    // pop all states that depends on the inputs were modifying
    while (states.items.len > 0 and states.items.len - 1 > tick) {
        _ = states.pop() orelse js.debug.fail("impossible");
    }

    // pop all input entries after and on this tick
    while (peerInputArray.items.len > tick) {
        _ = peerInputArray.pop() orelse js.debug.fail("impossible");
    }

    // fill holes by duplicating the last inputs before this tick
    if (peerInputArray.items.len > 0 and peerInputArray.items.len < tick) {
        const last = peerInputArray.getLast();

        while (peerInputArray.items.len < tick) {
            const head = try peerInputArray.addOne(wal);
            head.* = last;
        }
    }

    const head = try peerInputArray.addOne(wal);
    head.* = input_buffer;
}
