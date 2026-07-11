const std = @import("std");

pub var allow_log = true;

extern fn js_log_str(ptr: [*]u8, len: u32) void;

extern fn js_clear() void;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    if (!allow_log) return;
    const slice = std.fmt.allocPrint(std.heap.wasm_allocator, fmt, args) catch unreachable;
    js_log_str(slice.ptr, slice.len);
    std.heap.wasm_allocator.free(slice);
}

pub fn logScalar(arg: anytype) void {
    if (!allow_log) return;
    log("{any}", .{arg});
}

pub fn clear() void {
    js_clear();
}

pub fn fail(arg: anytype) noreturn {
    log("{any}", .{arg});
    unreachable;
}
