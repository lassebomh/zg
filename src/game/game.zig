const std = @import("std");

const debug = @import("../js/debug.zig");
const Input = @import("../js/inputs.zig").Input;
const gl = @import("../js/wgl2.zig");
const ObjMesh = @import("../lib/obj.zig").ObjMesh;
const lib = @import("../lib/root.zig");
const RGBA = lib.RGBA;
const v2 = lib.v2;
const m = @import("../math/main.zig");
const game = @import("./root.zig");

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
        _ = this; // autofix
        _ = prev; // autofix
        _ = alpha; // autofix
        _ = screen; // autofix
        _ = peer_id; // autofix

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
    \\in vec3 normal;
    \\in vec3 color;
    \\
    \\out vec3 vColor;
    \\out float vBrightness;
    \\
    \\uniform mat4 uProjection;
    \\uniform mat4 uView;
    \\
    \\void main() {
    \\  vColor = color;
    \\  vBrightness = max(dot(vec3(0, -1, 0), normal), 0.0);
    \\  gl_Position = uProjection * uView * model * vec4(position, 1.0);
    \\}
;

const fragmentSource =
    \\#version 300 es
    \\precision mediump float;
    \\
    \\in vec3 vColor;
    \\in float vBrightness;
    \\
    \\out vec4 fragColor;
    \\
    \\void main() {
    \\  fragColor = vec4(vColor, 1.0);
    \\}
;

pub const Render = struct {
    const This = @This();

    program: *anyopaque = undefined,
    vao: *anyopaque = undefined,
    t: i32 = 0,

    uTime: *anyopaque = undefined,
    uProjection: *anyopaque = undefined,
    uView: *anyopaque = undefined,

    aModels: *anyopaque = undefined,

    aColors: *anyopaque = undefined,

    bVertPos: *anyopaque = undefined,
    bVertIdxs: *anyopaque = undefined,

    bNormals: *anyopaque = undefined,
    bNormalIdxs: *anyopaque = undefined,

    tempObj: ObjMesh = undefined,

    pub fn create(gpa: std.mem.Allocator) !This {
        var this = This{};

        this.program = gl.createProgram();
        gl.enable(.DEPTH_TEST);
        gl.enable(.CULL_FACE);

        const vs = gl.createShader(gl.GLEnum_Shader.VERTEX_SHADER);
        gl.shaderSource(vs, vertexSource);
        gl.compileShader(vs);
        gl.attachShader(this.program, vs);

        const fs = gl.createShader(gl.GLEnum_Shader.FRAGMENT_SHADER);
        gl.shaderSource(fs, fragmentSource);
        gl.compileShader(fs);
        gl.attachShader(this.program, fs);

        gl.linkProgram(this.program);

        this.vao = gl.createVertexArray();
        gl.bindVertexArray(this.vao);

        {
            this.bVertPos = gl.createBuffer();
            gl.bindBuffer(.ARRAY_BUFFER, this.bVertPos);

            this.bVertIdxs = gl.createBuffer();
            gl.bindBuffer(.ELEMENT_ARRAY_BUFFER, this.bVertIdxs);

            const loc = gl.getAttribLocation(this.program, "position");
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(loc, 3, .FLOAT, false, 0, 0);
            gl.vertexAttribDivisor(loc, 0);
        }
        {
            // this.bNormals = gl.createBuffer();
            // gl.bindBuffer(.ARRAY_BUFFER, this.bNormals);

            // this.bNormalIdxs = gl.createBuffer();
            // gl.bindBuffer(.ELEMENT_ARRAY_BUFFER, this.bNormalIdxs);

            // const loc = gl.getAttribLocation(this.program, "normal");
            // gl.enableVertexAttribArray(loc);
            // gl.vertexAttribPointer(loc, 3, .FLOAT, false, 0, 0);
            // gl.vertexAttribDivisor(loc, 0);
        }

        {
            this.aModels = gl.createBuffer();
            gl.bindBuffer(.ARRAY_BUFFER, this.aModels);
            const loc = gl.getAttribLocation(this.program, "model");
            for (0..4) |i| {
                const li: i32 = @intCast(i);
                gl.enableVertexAttribArray(loc + li);
                gl.vertexAttribPointer(loc + li, 4, .FLOAT, false, 16 * 4, li * 4 * 4);
                gl.vertexAttribDivisor(loc + li, 1);
            }
        }
        {
            this.aColors = gl.createBuffer();
            gl.bindBuffer(.ARRAY_BUFFER, this.aColors);

            const loc = gl.getAttribLocation(this.program, "color");
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(loc, 3, .FLOAT, false, 0, 0);
            gl.vertexAttribDivisor(loc, 1);
        }

        this.uProjection = gl.getUniformLocation(this.program, "uProjection");
        this.uView = gl.getUniformLocation(this.program, "uView");

        // this.tempObj = try ObjMesh.fromFile(@embedFile("../models/default_cube.obj"), gpa);
        this.tempObj = try ObjMesh.fromFile(@embedFile("../models/icosphere_3.obj"), gpa);

        return this;
    }

    pub fn render(this: *This, gpa: std.mem.Allocator) !void {
        _ = gpa; // autofix
        this.t += 1;
        const f: f32 = @floatFromInt(this.t);

        const obj = this.tempObj;

        const colors = [_]m.Vec3{
            m.Vec3.init(1, 1, 0),
            m.Vec3.init(1, 1, 0),
        };

        const models = [_]m.Mat4x4{
            m.Mat4x4.ident,
            m.Mat4x4.translate(.init(1, 0, 0)),
        };

        var clear: i32 = 0;
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.COLOR_BUFFER_BIT);
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.DEPTH_BUFFER_BIT);
        gl.clear(clear);

        gl.useProgram(this.program);
        gl.bindVertexArray(this.vao);

        gl.bindBuffer(.ARRAY_BUFFER, this.aModels);
        gl.bufferDataM4x4(.ARRAY_BUFFER, &models, .STATIC_DRAW);

        gl.bindBuffer(.ARRAY_BUFFER, this.bVertPos);
        gl.bufferDataF32(.ARRAY_BUFFER, obj.verts, .STATIC_DRAW);

        gl.bindBuffer(.ELEMENT_ARRAY_BUFFER, this.bVertIdxs);
        gl.bufferDataU32(.ELEMENT_ARRAY_BUFFER, obj.face_vert_idxs, .STATIC_DRAW);

        // gl.bindBuffer(.ARRAY_BUFFER, this.bNormals);
        // gl.bufferDataF32(.ARRAY_BUFFER, obj.normals, .STATIC_DRAW);

        // gl.bindBuffer(.ELEMENT_ARRAY_BUFFER, this.bNormalIdxs);
        // gl.bufferDataU32(.ELEMENT_ARRAY_BUFFER, obj.face_normal_idxs, .STATIC_DRAW);

        gl.bindBuffer(.ARRAY_BUFFER, this.aColors);
        gl.bufferDataV3(.ARRAY_BUFFER, &colors, .STATIC_DRAW);

        // const uProj = m.Mat4x4.projection2D(.{ .left = -30, .right = 30, .bottom = -30, .top = 30, .near = -1200, .far = 1200 });
        const uProj = m.Mat4x4.perspective(.{ .fov = 0.5, .aspect = 1.0, .near = 0.1, .far = 1000.0 });
        gl.uniformMatrix4fv(this.uProjection, false, uProj);

        const uView = m.Mat4x4.translate(.init(0, 0, -10))
            .mul(&m.Mat4x4.rotateX(@sin(f / 80)))
            .mul(&m.Mat4x4.rotateY(f / 200));

        gl.uniformMatrix4fv(this.uView, false, uView);

        gl.drawElementsInstanced(.TRIANGLES, @intCast(obj.face_vert_idxs.len), .UNSIGNED_INT, 0, @intCast(models.len));
    }
};
