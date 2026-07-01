const std = @import("std");

pub const RGBA = extern struct {
    r: u8,
    g: u8,
    b: u8,
    alpha: u8,

    pub fn fromHex(hex: []const u8) RGBA {
        var rgba = RGBA{
            .r = std.fmt.parseUnsigned(u8, hex[1..3], 16) catch unreachable,
            .g = std.fmt.parseUnsigned(u8, hex[3..5], 16) catch unreachable,
            .b = std.fmt.parseUnsigned(u8, hex[5..7], 16) catch unreachable,
            .alpha = 255,
        };
        if (hex.len == 9) {
            rgba.alpha = std.fmt.parseUnsigned(u8, hex[7..9], 16) catch unreachable;
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

pub const v3 = packed struct(u48) {
    pub fn radians_xy(angle: f32) v3.Value {
        return .{ @cos(angle), @sin(angle), 0 };
    }

    pub const Value = @Vector(3, f32);

    pub const zero = fill(0);
    pub const one = fill(1);

    pub fn xyz(x: f32, y: f32, z: f32) v3.Value {
        return .{ x, y, z };
    }

    pub fn fill(value: f32) v3.Value {
        return @splat(value);
    }

    pub const lerp = std.math.lerp;

    pub fn length(vec: v3.Value) f32 {
        return @sqrt(vec[0] * vec[0] + vec[1] * vec[1] + vec[2] * vec[2]);
    }

    pub fn distance(a: v3.Value, b: v3.Value) f32 {
        return v3.length(a - b);
    }

    pub fn dot(a: v3.Value, b: v3.Value) f32 {
        return @reduce(.Add, a * b);
    }

    pub fn cross(a: v3.Value, b: v3.Value) v3.Value {
        return .{
            a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0],
        };
    }

    pub fn normalize(vec: v3.Value) v3.Value {
        const dist = v3.length(vec);
        if (dist == 0) {
            return v3.zero;
        } else {
            return vec / v3.fill(dist);
        }
    }

    pub fn clamp_length(vec: v3.Value, max_length: f32) v3.Value {
        const dist: f32 = @max(v3.length(vec), max_length);
        return vec / v3.fill(dist);
    }
};

pub const Box = struct {
    position: v2.Value,
    size: v2.Value,

    pub fn x_left(this: Box) f32 {
        return this.position[0] - this.size[0] / 2;
    }
    pub fn x_right(this: Box) f32 {
        return this.position[0] + this.size[0] / 2;
    }
    pub fn x_center(this: Box) f32 {
        return this.position[0];
    }
    pub fn y_top(this: Box) f32 {
        return this.position[1] - this.size[1] / 2;
    }
    pub fn y_bottom(this: Box) f32 {
        return this.position[1] + this.size[1] / 2;
    }
    pub fn y_center(this: Box) f32 {
        return this.position[1];
    }

    pub fn tl(this: Box) v2.Value {
        return v2.xy(this.x_left(), this.y_top());
    }
    pub fn tc(this: Box) v2.Value {
        return v2.xy(this.x_center(), this.y_top());
    }
    pub fn tr(this: Box) v2.Value {
        return v2.xy(this.x_right(), this.y_top());
    }
    pub fn cr(this: Box) v2.Value {
        return v2.xy(this.x_right(), this.y_center());
    }
    pub fn br(this: Box) v2.Value {
        return v2.xy(this.x_right(), this.y_bottom());
    }
    pub fn bc(this: Box) v2.Value {
        return v2.xy(this.x_center(), this.y_bottom());
    }
    pub fn bl(this: Box) v2.Value {
        return v2.xy(this.x_left(), this.y_bottom());
    }
    pub fn cl(this: Box) v2.Value {
        return v2.xy(this.x_left(), this.y_center());
    }

    pub fn cc(this: Box) v2.Value {
        return this.position;
    }

    pub fn lerp(this: Box, other: Box, alpha: f32) Box {
        const a = v2.fill(alpha);
        return Box{
            .position = v2.lerp(other.position, this.position, a),
            .size = v2.lerp(other.size, this.size, a),
            .vel = v2.lerp(other.vel, this.vel, a),
            .impact = v2.lerp(other.impact, this.impact, a),
        };
    }

    pub fn right_distance_to(this: Box, other: Box) f32 {
        return other.x_left() - this.x_right();
    }

    pub fn left_distance_to(this: Box, other: Box) f32 {
        return this.x_left() - other.x_right();
    }

    pub fn top_distance_to(this: Box, other: Box) f32 {
        return this.y_top() - other.y_bottom();
    }

    pub fn bottom_distance_to(this: Box, other: Box) f32 {
        return other.y_top() - this.y_bottom();
    }
};

pub fn Container(comptime T: type, comptime capacity: comptime_int) type {
    const Error = error{OutOfMemory};

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

        pub fn addOne(self: *Self) Error!*T {
            if (self.len == capacity) {
                return Error.OutOfMemory;
            }
            const index = self.len;
            self.len += 1;
            const id = self.ids[index];
            var item = &self.items[id];
            item.id = id; // Here we assume the existense of an "id" field.
            return item;
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
