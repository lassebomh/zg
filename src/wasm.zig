const std = @import("std");
const lib = @import("./lib/root.zig");
const v2 = lib.v2;

const js = @import("./js/root.zig");
const game = @import("./game/root.zig");

const wal = std.heap.wasm_allocator;
const ArrayList = std.ArrayList;

// MARK: TODO REMOVE vec shorthand in inputs

var states: ArrayList(game.State) = .empty;

var peersInputs: [4]ArrayList(js.inputs.Inputs) = .{
    .empty, // peer 1
    .empty, // peer 2
    .empty, // peer 3
    .empty, // peer 4
};

var jsPeersInput: js.inputs.Inputs = std.mem.zeroes(js.inputs.Inputs);

export fn getInputsPtr() *js.inputs.Inputs {
    return &jsPeersInput;
}

fn render(tick: i32, alpha: f32, screen: v2.Value, peer_id: i32) !void {
    // js.debug.log("{} {} {} {}", .{ tick, alpha, screen, peer_id });
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

        var input_frame: [4]js.inputs.Inputs = undefined;

        for (peersInputs, 0..4, 1..5) |peer_inputs, i, inputs_peer_id| {
            var inputs = &input_frame[i];

            if (peer_inputs.items.len == 0) {
                inputs.peer_id = @intCast(inputs_peer_id);
            } else {
                const inputs_tick: usize = @min(new_tick - 1, peer_inputs.items.len - 1);
                inputs.* = peer_inputs.items[inputs_tick];
            }
        }

        new_state.update(&input_frame);

        const new_state_ref = try states.addOne(wal);
        new_state_ref.* = new_state.*;
    }

    const state_left = &states.items[utick];
    const state_right = &states.items[utick + 1];

    state_right.render(state_left, alpha, screen, peer_id);
}

export fn jsRenderTick(itick: i32, alpha: f32, screen_width: i32, screen_height: i32, peer_id: i32) void {
    // js.debug.log("render: {} {} {} {} {}", .{ itick, alpha, screen_width, screen_height, peer_id });
    const screen: v2.Value = .{
        @floatFromInt(screen_width),
        @floatFromInt(screen_height),
    };

    render(itick, alpha, screen, peer_id) catch |e| {
        js.debug.fail("{any}", .{e});
    };
}

export fn jsPullInputs(itick: i32) void {
    // js.debug.log("pull inputs: {}", .{itick});

    pullInputs(itick) catch |e| {
        js.debug.fail("{any}", .{e});
    };
}

fn pullInputs(itick: i32) !void {
    const tick: usize = @intCast(itick);
    // js.debug.log("tick {}", .{tick});
    const peer_id = jsPeersInput.peer_id;
    // js.debug.log("peer_id {}", .{peer_id});
    const peer_index: usize = @intCast(peer_id);
    // js.debug.log("peer_index {}", .{peer_index});
    var peerInputArray = peersInputs[peer_index];
    // js.debug.log("peerInputArray {}", .{peerInputArray});

    try peerInputArray.ensureTotalCapacity(wal, tick + 1);
    // js.debug.log("peerInputArray {}", .{peerInputArray});

    // js.debug.log("pop count = {}", .{tick - (states.items.len - 1)});

    // pop all states that depends on the inputs were modifying
    while (states.items.len - 1 > tick) {
        _ = states.pop() orelse js.debug.fail("impossible", .{});
    }

    // js.debug.log("pop inputs count = {}", .{tick - (peerInputArray.items.len)});
    // pop all input entries after and on this tick
    while (peerInputArray.items.len > tick) {
        _ = peerInputArray.pop() orelse js.debug.fail("impossible", .{});
    }

    // fill holes by duplicating the last inputs before this tick
    if (peerInputArray.items.len > 0 and peerInputArray.items.len < tick) {
        // js.debug.log("get last", .{});
        const last = peerInputArray.getLast();

        // js.debug.log("clone = {}", .{tick - peerInputArray.items.len});
        while (peerInputArray.items.len < tick) {
            const head = try peerInputArray.addOne(wal);
            head.* = last;
        }
    }

    // js.debug.log("1: add one = {}", .{peerInputArray});
    const head = try peerInputArray.addOne(wal);
    // js.debug.log("2: add one = {}", .{peerInputArray});
    head.* = jsPeersInput;
    js.debug.log("input({}) = {}", .{ tick, head.* });
}
