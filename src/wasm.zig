const std = @import("std");
const lib = @import("./lib/root.zig");
const v2 = lib.v2;

const debug = @import("./js/debug.zig");
const game = @import("./game/root.zig");
const Input = @import("./js/inputs.zig").Input;

const wal = std.heap.wasm_allocator;
const ArrayList = std.ArrayList;

var states: ArrayList(game.State) = .empty;

var peers_inputs: [4]ArrayList(Input) = .{
    .empty, // peer 1
    .empty, // peer 2
    .empty, // peer 3
    .empty, // peer 4
};

var input_buffer: Input = std.mem.zeroes(Input);

export fn jsGetInputBufferPtr() *Input {
    return &input_buffer;
}

export fn jsGetPeerInputsPtr(peer_id: i32) [*]Input {
    return peers_inputs[@intCast(peer_id - 1)].items.ptr;
}
export fn jsGetPeerInputsLen(peer_id: i32) usize {
    return peers_inputs[@intCast(peer_id - 1)].items.len;
}

export fn jsRenderTick(tick: i32, screen_width: i32, screen_height: i32, peer_id: i32) void {
    const screen: v2.Value = .{
        @floatFromInt(screen_width),
        @floatFromInt(screen_height),
    };

    render(tick, screen, peer_id) catch |e| debug.fail(e);
}

export fn jsPullInputBuffer(itick: i32) void {
    pull_input_buffer(itick) catch |e| debug.fail(e);
}

fn render(tick: i32, screen: v2.Value, peer_id: i32) !void {
    const utick: usize = @intCast(tick);

    // ensure it can hold tick and tick+1
    try states.ensureTotalCapacity(wal, utick + 1);

    // create the genesis state if it doesn't exist
    if (states.items.len == 0) {
        const genesis = try states.addOne(wal);
        genesis.* = game.State.init();
    }

    // ensure all necessary state exist
    while (states.items.len < tick + 1) {
        const new_tick = states.items.len;

        var prev_state_copy = states.items[new_tick - 1];
        var new_state = &prev_state_copy;
        var state_inputs: [4]Input = undefined;

        for (peers_inputs, 0..4, 1..5) |inputs, i, inputs_peer_id| {
            var input = &state_inputs[i];
            if (inputs.items.len == 0) {
                input.peer_id = @intCast(inputs_peer_id);
            } else {
                const inputs_tick: usize = @min(new_tick - 1, inputs.items.len - 1);
                input.* = inputs.items[inputs_tick];
            }
        }

        debug.allow_log = @as(i32, @intCast(new_tick)) == tick;
        if (debug.allow_log) {
            debug.clear();
        }

        new_state.update(&state_inputs);
        debug.allow_log = false;

        const new_state_ref = try states.addOne(wal);
        new_state_ref.* = new_state.*;
    }

    const state = &states.items[utick];

    state.render(screen, peer_id);
}

fn pull_input_buffer(itick: i32) !void {
    const tick: usize = @intCast(itick);
    const peer_id = input_buffer.peer_id;
    const peer_index: usize = @intCast(peer_id - 1);
    var peerInputArray = &peers_inputs[peer_index];

    try peerInputArray.ensureTotalCapacity(wal, tick + 1);

    // pop all states that depends on the inputs were modifying
    while (states.items.len > 0 and states.items.len - 1 > tick) {
        _ = states.pop() orelse debug.fail("impossible");
    }

    // pop all input entries after and on this tick
    while (peerInputArray.items.len > tick) {
        _ = peerInputArray.pop() orelse debug.fail("impossible");
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
