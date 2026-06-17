const std = @import("std");

pub fn Container(comptime T: type, comptime capacity: comptime_int) type {
    const TContainer = struct {
        const Self = @This();

        ids: [capacity]usize, // ids[index] = id
        ixs: [capacity]usize, // ixs[id] = index
        items: [capacity]T,
        len: usize,

        pub fn init() Self {
            var out = Self{
                .ids = undefined,
                .ixs = undefined,
                .items = undefined,
                .len = 0,
            };

            for (0..capacity) |x| {
                out.ids[x] = @intCast(x);
                out.ixs[x] = @intCast(x);
            }

            return out;
        }

        pub fn new(self: *Self) struct { id: usize, item: *T } {
            if (self.len == capacity) {
                unreachable;
            }
            const index = self.len;
            self.len += 1;
            const id = self.ids[index];
            return .{ .id = id, .item = &self.items[id] };
        }

        pub fn get(self: *Self, id: usize) ?*T {
            const index = self.ixs[id];
            if (index >= self.len) {
                return null;
            }
            return &self.items[index];
        }

        pub fn delete(self: *Self, id: usize) void {
            const index = self.ixs[id];
            if (index >= self.len) {
                unreachable;
            }
            const tail = self.len - 1;

            self.items[index] = self.items[tail];
            self.items[tail] = std.mem.zeroes(T);

            const tailId = self.ids[tail];
            const indexId = self.ids[index];

            self.ids[index] = tailId;
            self.ids[tail] = indexId;

            self.ixs[tailId] = index;
            self.ixs[indexId] = tail;

            self.len -= 1;
        }
    };

    return TContainer;
}
