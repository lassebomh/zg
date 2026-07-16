const std = @import("std");

const debug = @import("../js/debug.zig");
const m = @import("../math/main.zig");
const vec2 = m.Vec2;
const vec3 = m.Vec3;
const vec4 = m.Vec4;
const quat = m.Quat;
const mat4 = m.Mat4x4;

pub fn Container(comptime T: type, comptime capacity: comptime_int) type {
    const Error = error{OutOfMemory};

    const TContainer = struct {
        const This = @This();

        ids: [capacity]usize, // ids[index] = id
        ixs: [capacity]usize, // ixs[id] = index
        items: [capacity]T,
        len: usize,

        pub fn init() This {
            var out = This{
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

        pub fn addOne(self: *This) Error!*T {
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

        pub fn get(self: *This, id: usize) ?*T {
            const index = self.ixs[id];
            if (index >= self.len) {
                return null;
            }
            return &self.items[index];
        }

        pub fn delete(self: *This, id: usize) void {
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

        pub fn iter(this: *This) []T {
            return this.items[0..this.len];
        }
    };

    return TContainer;
}

pub fn SecondOrder(T: type) type {
    return struct {
        const This = @This();

        previous: T,
        value: T,
        velocity: T,
        k1: f32,
        k2: f32,
        k3: f32,

        first: bool,

        pub fn init(naturalFreq: f32, dampingRatio: f32, response: f32) This {
            return .{
                .k1 = dampingRatio / (std.math.pi * naturalFreq),
                .k2 = 1 / ((2 * std.math.pi * naturalFreq) * (2 * std.math.pi * naturalFreq)),
                .k3 = response * dampingRatio / (2 * std.math.pi * naturalFreq),
                .previous = std.mem.zeroes(T),
                .value = std.mem.zeroes(T),
                .velocity = std.mem.zeroes(T),
                .first = true,
            };
        }

        pub fn update(this: *This, dt: f32, newValue: T) void {
            if (dt == 0) {
                return;
            }

            if (this.first) {
                this.value = newValue;
                this.previous = newValue;
                this.first = false;
            }

            const deltaSeconds = @max(@abs(dt / 1000), 0.00001);

            const xd = newValue.sub(this.previous).divScalar(deltaSeconds);

            const k2_stable = @max(
                this.k2,
                deltaSeconds * deltaSeconds * 0.5 + deltaSeconds * this.k1 * 0.5,
                deltaSeconds * this.k1,
            );

            this.value = this.value.add(this.velocity.mulScalar(deltaSeconds));

            const accel = newValue
                .add(xd.mulScalar(this.k3))
                .sub(this.value)
                .sub(this.velocity.mulScalar(this.k1))
                .divScalar(k2_stable);

            this.velocity = this.velocity.add(accel.mulScalar(deltaSeconds));

            this.previous = newValue;
        }
    };
}

pub const SecondOrderQuat = struct {
    const This = @This();

    previous: quat,
    value: quat,
    velocity: quat,
    k1: f32,
    k2: f32,
    k3: f32,
    first: bool,

    pub fn init(naturalFreq: f32, dampingRatio: f32, response: f32) This {
        const pi = std.math.pi;
        return .{
            .k1 = dampingRatio / (pi * naturalFreq),
            .k2 = 1.0 / ((2.0 * pi * naturalFreq) * (2.0 * pi * naturalFreq)),
            .k3 = response * dampingRatio / (2.0 * pi * naturalFreq),
            .previous = quat.identity(),
            .value = quat.identity(),
            .velocity = quat.init(0, 0, 0, 0),
            .first = true,
        };
    }

    fn shortestPath(ref: *const quat, q: quat) quat {
        if (ref.dot(q) < 0) return q.mulScalar(-1);
        return q;
    }

    pub fn update(this: *This, dt: f32, newValue: quat) void {
        if (dt == 0) return;

        if (this.first) {
            this.value = newValue;
            this.previous = newValue;
            this.first = false;
            return;
        }

        const target = shortestPath(&this.value, newValue);
        const prev = shortestPath(&target, this.previous);

        const deltaSeconds = @max(@abs(dt / 1000.0), 0.00001);

        const xd = target.sub(prev).divScalar(deltaSeconds);

        const k2_stable = @max(
            this.k2,
            deltaSeconds * deltaSeconds * 0.5 + deltaSeconds * this.k1 * 0.5,
            deltaSeconds * this.k1,
        );

        this.value = this.value.add(this.velocity.mulScalar(deltaSeconds));

        const accel = target
            .add(xd.mulScalar(this.k3))
            .sub(this.value)
            .sub(this.velocity.mulScalar(this.k1))
            .divScalar(k2_stable);

        this.velocity = this.velocity.add(accel.mulScalar(deltaSeconds));

        this.value = this.value.normalize();
        this.previous = target;
    }
};

comptime {
    _ = SecondOrder(vec3);
    _ = SecondOrder(vec2);
    _ = SecondOrderQuat;
}
