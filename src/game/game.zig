const std = @import("std");

const Input = @import("../js/inputs.zig").Input;

const game = @import("./root.zig");
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;

const debug = @import("../js/debug.zig");
const m = @import("../math/main.zig");

pub const State = struct {
    avatars: lib.Container(game.Avatar, game.MaxPlayers), // should multiply if controllers are supported,
    players: lib.Container(game.Player, game.MaxPlayers),
    level: game.Level,

    pub fn update(this: *State, inputs: []Input) void {
        for (inputs) |input| {
            if (input.peer_id == 0) continue;

            var player: *game.Player = upsert_player: {
                for (this.players.items[0..this.players.len]) |*p| {
                    if (p.peer_id == input.peer_id) {
                        break :upsert_player p;
                    }
                }

                const new_player = this.players.addOne() catch |e| debug.fail(e);

                new_player.id = new_player.id;
                new_player.peer_id = input.peer_id;

                break :upsert_player new_player;
            };
            player.input = input;
            player.update(this);
        }

        for (this.avatars.items[0..this.avatars.len]) |*avatar| {
            avatar.update(this);
        }
        // update_boxes(&this.boxes);
    }

    pub fn render(this: *State, prev: *State, alpha: f32, screen: v2.Value, peer_id: i32) void {
        _ = this;
        _ = prev;
        _ = alpha;
        _ = screen;
        _ = peer_id;
        // defer js.ctx.flush();

        // js.ctx.save();
        // defer js.ctx.restore();

        // js.ctx.clearRect(v2.zero, screen);

        // js.ctx.fillStyle(RGBA.fromHex("#000000"));
        // js.ctx.fillRect(v2.zero, screen);

        // js.ctx.translate(screen / v2.fill(2));
        // js.ctx.scale(v2.fill(5));

        // for (this.players.items) |player| {
        //     if (player.peer_id == peer_id) {
        //         const avatar = this.avatars.get(player.avatar_id orelse break).?;
        //         const prev_avatar = prev.avatars.get(avatar.id) orelse avatar;
        //         const pos = v2.lerp(prev_avatar.collision.position, avatar.collision.position, v2.fill(alpha));
        //         js.ctx.translate(-pos);
        //         break;
        //     }
        // }

        // this.level.render();

        // for (0..this.avatars.len) |avatar_i| {
        //     const avatar = &this.avatars.items[avatar_i];
        //     const avatar_id = this.avatars.ids[avatar_i];
        //     const prev_avatar = prev.avatars.get(avatar_id) orelse continue;
        //     avatar.render(prev_avatar, alpha);
        // }
    }

    pub fn init() State {
        const state: State = .{
            .avatars = lib.Container(game.Avatar, game.MaxPlayers).init(),
            .players = lib.Container(game.Player, game.MaxPlayers).init(),
            .level = game.Level.init() catch |e| debug.fail(e),
        };

        return state;
    }
};

const vertexSource =
    \\#version 300 es
    \\
    \\in mat4 model;
    \\in vec3 position;
    \\in vec3 color;
    \\
    \\out vec3 vColor;
    \\
    \\uniform mat4 uProjection;
    \\uniform mat4 uView;
    \\
    \\void main() {
    \\  vColor = color;
    \\  gl_Position = uProjection * uView * model * vec4(position, 1.0);
    \\}
;

const fragmentSource =
    \\#version 300 es
    \\precision mediump float;
    \\
    \\// uniform float uTime;
    \\
    \\in vec3 vColor;
    \\
    \\out vec4 fragColor;
    \\
    \\void main() {
    \\  fragColor = vec4(vColor, 1.0);
    \\}
;

const unit_cube_vertices = [_]f32{
    // front-bottom-left
    -0.5, -0.5, -0.5,
    // front-bottom-right
    0.5,  -0.5, -0.5,
    // front-top-right
    0.5,  0.5,  -0.5,
    // front-top-left
    -0.5, 0.5,  -0.5,
    // back-bottom-left
    -0.5, -0.5, 0.5,
    // back-bottom-right
    0.5,  -0.5, 0.5,
    // back-top-right
    0.5,  0.5,  0.5,
    // back-top-left
    -0.5, 0.5,  0.5,
};

// const models = [_]m.Mat4x4{
//     m.Mat4x4.translate(.init(1, 0, 0)),
//     m.Mat4x4.translate(.init(-1, 0, 0)),
//     // m.Mat4x4.translate(.init(0, 1, 0)),
//     // m.Mat4x4.translate(.init(0, -1, 0)),
// };

const grid_w = 50;
const grid_h = 50;

var models: [grid_w * grid_h]m.Mat4x4 = undefined;

const gl = @import("../js/wgl2.zig");

pub const Render = struct {
    const This = @This();

    program: *anyopaque,
    vao: *anyopaque,
    t: i32,

    uTime: *anyopaque,
    uProjection: *anyopaque,
    uView: *anyopaque,
    aModels: *anyopaque,

    pub fn create() This {
        const program = gl.createProgram();
        gl.enable(.DEPTH_TEST);
        gl.enable(.CULL_FACE);

        const vs = gl.createShader(gl.GLEnum_Shader.VERTEX_SHADER);
        gl.shaderSource(vs, vertexSource);
        gl.compileShader(vs);
        gl.attachShader(program, vs);

        const fs = gl.createShader(gl.GLEnum_Shader.FRAGMENT_SHADER);
        gl.shaderSource(fs, fragmentSource);
        gl.compileShader(fs);
        gl.attachShader(program, fs);

        gl.linkProgram(program);

        const vao = gl.createVertexArray();
        gl.bindVertexArray(vao);

        {
            const buffer = gl.createBuffer();
            gl.bindBuffer(.ARRAY_BUFFER, buffer);
            gl.bufferDataF32(.ARRAY_BUFFER, &unit_cube_vertices, .STATIC_DRAW);

            const indexBuffer = gl.createBuffer();
            gl.bindBuffer(.ELEMENT_ARRAY_BUFFER, indexBuffer);
            gl.bufferDataU32(.ELEMENT_ARRAY_BUFFER, &.{
                // front face
                0, 2, 1,
                0, 3, 2,
                // back face
                5, 7, 4,
                5, 6, 7,
                // left face
                4, 3, 0,
                4, 7, 3,
                // right face
                1, 6, 5,
                1, 2, 6,
                // top face
                3, 6, 2,
                3, 7, 6,
                // bottom face
                4, 1, 5,
                4, 0, 1,
            }, .STATIC_DRAW);

            const loc = gl.getAttribLocation(program, "position");
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(loc, 3, .FLOAT, false, 0, 0);
            gl.vertexAttribDivisor(loc, 0);
        }

        const aModels = gl.createBuffer();
        {
            gl.bindBuffer(.ARRAY_BUFFER, aModels);
            gl.bufferDataM4x4(.ARRAY_BUFFER, &models, .STATIC_DRAW);

            const loc = gl.getAttribLocation(program, "model");
            for (0..4) |i| {
                const li: i32 = @intCast(i);
                gl.enableVertexAttribArray(loc + li);
                gl.vertexAttribPointer(loc + li, 4, .FLOAT, false, 16 * 4, li * 4 * 4);
                gl.vertexAttribDivisor(loc + li, 1);
            }
        }
        {
            const buffer = gl.createBuffer();
            gl.bindBuffer(.ARRAY_BUFFER, buffer);

            const data = [_]f32{
                1, 0, 1, 0, 1, 0, 0, 0, 1,
                1, 0, 1, 0, 0, 1, 0, 1, 0,
                1, 0, 1, 0, 1, 0, 0, 0, 1,
                1, 0, 1, 0, 0, 1, 0, 1, 0,
                1, 0, 1, 0, 0, 1, 0, 1, 0,
                1, 0, 1, 0, 1, 0, 0, 1, 0,
                1, 0, 1, 0, 1, 0, 0, 0, 1,
                1, 0, 1, 0, 0, 1, 0, 1, 0,
                1, 0, 1, 0, 0, 1, 0, 0, 1,
                1, 0, 1, 0, 0, 1, 0, 1, 0,
                1, 0, 0, 0, 1, 0, 0, 0, 1,
                1, 0, 1, 0, 0, 1, 0, 1, 0,
            };
            gl.bufferDataF32(.ARRAY_BUFFER, &data, .STATIC_DRAW);

            const loc = gl.getAttribLocation(program, "color");
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(loc, 3, .FLOAT, false, 0, 0);
            gl.vertexAttribDivisor(loc, 0);
        }

        // const uTime = gl.getUniformLocation(program, "uTime");
        const uProjection = gl.getUniformLocation(program, "uProjection");
        const uView = gl.getUniformLocation(program, "uView");

        return .{
            .t = 0,
            .program = program,
            .vao = vao,
            .uTime = undefined,
            .uProjection = uProjection,
            .uView = uView,
            .aModels = aModels,
        };
    }

    pub fn render(this: *This) void {
        this.t += 1;
        const f: f32 = @floatFromInt(this.t);

        // const i: usize = @mod(@as(usize, @intCast(this.t)), models.len);

        for (0..grid_w) |x| {
            for (0..grid_h) |y| {
                var fx: f32 = @floatFromInt(x);
                fx -= @floatFromInt(grid_w / 2);

                var fy: f32 = @floatFromInt(y);
                fy -= @floatFromInt(grid_h / 2);
                const j = @cos((fx + fy) / 5 + f / 100);
                models[y * grid_w + x] = m.Mat4x4.translate(.init(fx, j, fy)); //.mul(&m.Mat4x4.rotateY(j / 2)).mul(&m.Mat4x4.rotateX(-j / 2));
            }
        }

        gl.bindBuffer(.ARRAY_BUFFER, this.aModels);
        gl.bufferDataM4x4(.ARRAY_BUFFER, &models, .STATIC_DRAW);

        var clear: i32 = 0;
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.COLOR_BUFFER_BIT);
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.DEPTH_BUFFER_BIT);
        gl.clear(clear);

        gl.useProgram(this.program);
        gl.bindVertexArray(this.vao);

        // const uProj = m.Mat4x4.projection2D(.{ .left = -30, .right = 30, .bottom = -30, .top = 30, .near = -1200, .far = 1200 });
        const uProj = m.Mat4x4.perspective(.{ .fov = 2.0, .aspect = 1.0, .near = 0.1, .far = 100.0 });
        gl.uniformMatrix4fv(this.uProjection, false, uProj);

        const uView = m.Mat4x4.translate(.init(0, 0, -20))
            .mul(&m.Mat4x4.rotateX(@sin(f / 800)))
            .mul(&m.Mat4x4.rotateY(f / 2000));

        gl.uniformMatrix4fv(this.uView, false, uView);

        gl.drawElementsInstanced(.TRIANGLES, 36, .UNSIGNED_INT, 0, models.len);
    }
};
