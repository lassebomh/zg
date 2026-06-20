const std = @import("std");

pub const RGBA = extern struct {
    r: u32,
    g: u32,
    b: u32,
    alpha: u32,

    pub fn fromHex(comptime hex: []const u8) RGBA {
        var rgba = RGBA{
            .r = std.fmt.parseUnsigned(u32, hex[1..3], 16) catch unreachable,
            .g = std.fmt.parseUnsigned(u32, hex[3..5], 16) catch unreachable,
            .b = std.fmt.parseUnsigned(u32, hex[5..7], 16) catch unreachable,
            .alpha = 255,
        };
        if (hex.len == 9) {
            rgba.alpha = std.fmt.parseUnsigned(u32, hex[7..9], 16) catch unreachable;
        }
        return rgba;
    }

    pub fn fromHSL(degrees: f32, s: f32, l: f32) RGBA {
        const h = @mod(degrees, 360.0);
        const c = (1.0 - @abs(2.0 * l - 1.0)) * s;
        const hp = h / 60.0;
        const x = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
        const m = l - c / 2.0;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (hp < 1) {
            r = c;
            g = x;
        } else if (hp < 2) {
            r = x;
            g = c;
        } else if (hp < 3) {
            g = c;
            b = x;
        } else if (hp < 4) {
            g = x;
            b = c;
        } else if (hp < 5) {
            r = x;
            b = c;
        } else {
            r = c;
            b = x;
        }

        return RGBA{
            .r = @intFromFloat((r + m) * 255.0),
            .g = @intFromFloat((g + m) * 255.0),
            .b = @intFromFloat((b + m) * 255.0),
            .alpha = 255,
        };
    }
};

pub const v2 = packed struct(u32) {
    pub fn radians(angle: f32) v2.Value {
        return .{
            @cos(angle),
            @sin(angle),
        };
    }

    pub const Value = @Vector(2, f32);

    pub const zero = fill(0);
    pub const one = fill(1);

    pub fn xy(x: f32, y: f32) v2.Value {
        return .{ x, y };
    }
    pub fn fill(value: f32) v2.Value {
        return @splat(value);
    }

    pub const lerp = std.math.lerp;

    pub fn length(vec: v2.Value) f32 {
        return std.math.hypot(vec[0], vec[1]);
    }

    pub fn distance(a: v2.Value, b: v2.Value) f32 {
        return v2.length(a - b);
    }

    pub fn normalize(vec: v2.Value) v2.Value {
        const dist = v2.length(vec);
        if (dist == 0) {
            return v2.zero;
        } else {
            return vec / v2.fill(dist);
        }
    }
    pub fn clamp_length(vec: v2.Value, max_length: f32) v2.Value {
        const dist: f32 = @max(v2.length(vec), max_length);
        return vec / v2.fill(dist);
    }
};

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

        // pub fn get(self: *Self, id: ?usize) ?*T {
        //     if (id == null) return null;
        //     const index = self.ixs[id.?];

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
