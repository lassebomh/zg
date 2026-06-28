const std = @import("std");

pub var allow_log = true;

extern fn jsLogStr(ptr: [*]u8, len: u32) void;
extern fn jsClear() void;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    if (!allow_log) return;
    const slice = std.fmt.allocPrint(std.heap.wasm_allocator, fmt, args) catch unreachable;
    jsLogStr(slice.ptr, slice.len);
    std.heap.wasm_allocator.free(slice);
}

pub fn clear() void {
    jsClear();
}

pub fn fail(arg: anytype) noreturn {
    log("{any}", .{arg});
    unreachable;
}
