const std = @import("std");

extern fn jsLogStr(ptr: [*]u8, len: u32) void;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    const slice = std.fmt.allocPrint(std.heap.wasm_allocator, fmt, args) catch unreachable;
    jsLogStr(slice.ptr, slice.len);
    std.heap.wasm_allocator.free(slice);
}

pub fn fail(arg: anytype) noreturn {
    log("{any}", .{arg});
    unreachable;
}
