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

const sceneVertexSource =
    \\#version 300 es
    \\
    \\#define POS_QUANTIZATION 100.0
    \\
    \\in mat4 model;
    \\in mat4 normalModel;
    \\in vec3 position;
    \\in vec3 normal;
    \\in vec4 color;
    \\
    \\out vec4 vColor;
    \\out float vBrightness;
    \\
    \\uniform mat4 uProjection;
    \\uniform mat4 uView;
    \\
    \\void main() {
    \\  vColor = color;
    \\  vec4 world = model * vec4(position, 1.0);
    \\  vec4 worldNormal = normalModel * vec4(normal, 1.0);
    \\  world = round(world * POS_QUANTIZATION) / POS_QUANTIZATION;
    \\  vBrightness = max(dot(vec3(0, 1, 0), worldNormal.xyz), 0.0);
    \\  gl_Position = uProjection * uView * world;
    \\}
;

const sceneFragmentSource =
    \\#version 300 es
    \\precision mediump float;
    \\
    \\#define AMBIENT_LIGHT 0.1 
    \\
    \\in vec4 vColor;
    \\in float vBrightness;
    \\
    \\out vec4 fragColor;
    \\
    \\void main() {
    \\  fragColor = vec4(vColor * AMBIENT_LIGHT + vColor * vBrightness * (1.0 - AMBIENT_LIGHT));
    \\}
;

const compVertexSource =
    \\#version 300 es
    \\out vec2 vUV;
    \\void main() {
    \\  vUV = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    \\  gl_Position = vec4(vUV * 2.0 - 1.0, 0.0, 1.0);
    \\}
;

const compFragmentSource =
    \\#version 300 es
    \\precision highp float;
    \\
    \\uniform sampler2D uColor;
    \\uniform sampler2D uDepth;
    \\uniform float uNear;
    \\uniform float uFar;
    \\uniform vec2 uResolution;
    \\
    \\#define COLOR_QUANTIZATION 6.0
    \\#define EDGE_STRENGTH 1.0
    \\
    \\in vec2 vUV;
    \\out vec4 fragColor;
    \\
    \\// ── Bayer 4x4 threshold ──────────────────────────────
    \\float bayerThreshold(vec2 pos) {
    \\  int x = int(mod(pos.x, 4.0));
    \\  int y = int(mod(pos.y, 4.0));
    \\  int index = x + y * 4;
    \\  float t;
    \\  if      (index == 0)  t =  0.0; else if (index == 1)  t =  8.0;
    \\  else if (index == 2)  t =  2.0; else if (index == 3)  t = 10.0;
    \\  else if (index == 4)  t = 12.0; else if (index == 5)  t =  4.0;
    \\  else if (index == 6)  t = 14.0; else if (index == 7)  t =  6.0;
    \\  else if (index == 8)  t =  3.0; else if (index == 9)  t = 11.0;
    \\  else if (index == 10) t =  1.0; else if (index == 11) t =  9.0;
    \\  else if (index == 12) t = 15.0; else if (index == 13) t =  7.0;
    \\  else if (index == 14) t = 13.0; else                  t =  5.0;
    \\  return (t + 0.5) / 16.0;
    \\}
    \\
    \\vec3 ditherColor(vec3 color, vec2 fragCoord, float levels) {
    \\  float threshold = bayerThreshold(fragCoord);
    \\  vec3 stepped = color * (levels - 1.0) + (threshold - 0.5);
    \\  return floor(clamp(stepped, 0.0, levels - 1.0) + 0.5) / (levels - 1.0);
    \\}
    \\float getDepth(int offsetX, int offsetY) {
    \\  vec2 invRes = 1.0 / uResolution;
    \\  float depth = texture(uDepth, vUV + vec2(offsetX, offsetY) * invRes).r;
    \\  float linear = uNear * uFar / (uFar - depth * (uFar - uNear));
    \\  return (linear - uNear) / (uFar - uNear);
    \\}
    \\
    \\float depthEdgeIndicator(float depth) {
    \\  float diff = 0.0;
    \\  diff += clamp(getDepth( 1, 0) - depth, 0.0, 1.0);
    \\  diff += clamp(getDepth(-1, 0) - depth, 0.0, 1.0);
    \\  diff += clamp(getDepth( 0, 1) - depth, 0.0, 1.0);
    \\  diff += clamp(getDepth( 0,-1) - depth, 0.0, 1.0);
    \\  return floor(smoothstep(0.01, 0.02, diff) * 2.0) / 2.0;
    \\}
    \\
    \\void main() {
    \\  vec4 color = texture(uColor, vUV);
    \\
    \\  float dei = depthEdgeIndicator(getDepth(0, 0));
    \\  float strength = dei > 0.0 ? (1.0 - dei * EDGE_STRENGTH) : 1.0;
    \\  
    \\  vec3 edged = color.rgb * strength;
    \\
    \\  vec3 dithered = ditherColor(edged, gl_FragCoord.xy, COLOR_QUANTIZATION);
    \\
    \\  fragColor = vec4(dithered, 1.0);
    \\}
;
pub const RenderObject = struct {
    const This = @This();

    vao: *anyopaque,

    aModels: *anyopaque,
    aNormalModels: *anyopaque,
    aColors: *anyopaque,

    normalModels: std.ArrayList(m.Mat4x4) = .empty,
    models: std.ArrayList(m.Mat4x4) = .empty,
    colors: std.ArrayList(m.Vec4) = .empty,

    data: []f32 = undefined,
    idxs: []u32 = undefined,

    pub fn add(this: *This, gpa: std.mem.Allocator, model: m.Mat4x4, color: m.Vec4) !void {
        const newModel = try this.models.addOne(gpa);
        newModel.* = model;
        const newNormalModel = try this.normalModels.addOne(gpa);
        newNormalModel.* = model.normalMatrix();
        const newColor = try this.colors.addOne(gpa);
        newColor.* = color;
    }

    pub fn init(gpa: std.mem.Allocator, program: *anyopaque, obj: ObjMesh) !RenderObject {
        var this = This{
            .vao = gl.createVertexArray(),
            .aModels = gl.createBuffer(),
            .aNormalModels = gl.createBuffer(),
            .aColors = gl.createBuffer(),
        };
        gl.bindVertexArray(this.vao);

        var idxs: std.ArrayList(u32) = .empty;
        var data: std.ArrayList(f32) = .empty;

        var hashmap: std.AutoHashMap([6]u32, u32) = .init(gpa);

        for (obj.face_vert_idxs, obj.face_normal_idxs) |vert_i, normal_i| {
            const vert = obj.verts[vert_i];
            const norm = obj.normals[normal_i];
            const values = [6]f32{ vert.x(), vert.y(), vert.z(), norm.x(), norm.y(), norm.z() };
            const key: [6]u32 = @bitCast(values);

            const dataIdx = hashmap.get(key) orelse brk: {
                const idx: u32 = @intCast(hashmap.count());
                try hashmap.put(key, idx);
                try data.appendSlice(gpa, &values);
                break :brk idx;
            };

            (try idxs.addOne(gpa)).* = dataIdx;
        }

        this.data = data.items;
        this.idxs = idxs.items;

        {
            const elementsBuffer = gl.createBuffer();
            gl.bindBuffer(.ARRAY_BUFFER, elementsBuffer);
            gl.bufferDataF32(.ARRAY_BUFFER, this.data, .STATIC_DRAW);

            const elementsIdxsBuffer = gl.createBuffer();
            gl.bindBuffer(.ELEMENT_ARRAY_BUFFER, elementsIdxsBuffer);
            gl.bufferDataU32(.ELEMENT_ARRAY_BUFFER, this.idxs, .STATIC_DRAW);

            const positionLoc = gl.getAttribLocation(program, "position");
            gl.enableVertexAttribArray(positionLoc);
            gl.vertexAttribPointer(positionLoc, 3, .FLOAT, false, 6 * 4, 0);
            gl.vertexAttribDivisor(positionLoc, 0);

            const normalLoc = gl.getAttribLocation(program, "normal");
            gl.enableVertexAttribArray(normalLoc);
            gl.vertexAttribPointer(normalLoc, 3, .FLOAT, false, 6 * 4, 3 * 4);
            gl.vertexAttribDivisor(normalLoc, 0);
        }
        {
            gl.bindBuffer(.ARRAY_BUFFER, this.aModels);
            const loc = gl.getAttribLocation(program, "model");
            for (0..4) |i| {
                const li: i32 = @intCast(i);
                gl.enableVertexAttribArray(loc + li);
                gl.vertexAttribPointer(loc + li, 4, .FLOAT, false, 16 * 4, li * 4 * 4);
                gl.vertexAttribDivisor(loc + li, 1);
            }
        }
        {
            gl.bindBuffer(.ARRAY_BUFFER, this.aNormalModels);
            const loc = gl.getAttribLocation(program, "normalModel");
            for (0..4) |i| {
                const li: i32 = @intCast(i);
                gl.enableVertexAttribArray(loc + li);
                gl.vertexAttribPointer(loc + li, 4, .FLOAT, false, 16 * 4, li * 4 * 4);
                gl.vertexAttribDivisor(loc + li, 1);
            }
        }
        {
            gl.bindBuffer(.ARRAY_BUFFER, this.aColors);

            const loc = gl.getAttribLocation(program, "color");
            gl.enableVertexAttribArray(loc);
            gl.vertexAttribPointer(loc, 4, .FLOAT, false, 0, 0);
            gl.vertexAttribDivisor(loc, 1);
        }

        return this;
    }

    pub fn render(this: *This) void {
        gl.bindVertexArray(this.vao);

        gl.bindBuffer(.ARRAY_BUFFER, this.aModels);
        gl.bufferDataM4x4(.ARRAY_BUFFER, this.models.items, .STATIC_DRAW);

        gl.bindBuffer(.ARRAY_BUFFER, this.aNormalModels);
        gl.bufferDataM4x4(.ARRAY_BUFFER, this.normalModels.items, .STATIC_DRAW);

        gl.bindBuffer(.ARRAY_BUFFER, this.aColors);
        gl.bufferDataV4(.ARRAY_BUFFER, this.colors.items, .STATIC_DRAW);

        gl.drawElementsInstanced(.TRIANGLES, @intCast(this.idxs.len), .UNSIGNED_INT, 0, @intCast(this.models.items.len));
        gl.bindVertexArray(null);

        this.models.clearRetainingCapacity();
        this.normalModels.clearRetainingCapacity();
        this.colors.clearRetainingCapacity();
    }
};

pub const Render = struct {
    const This = @This();

    t: i32 = 0,

    compProgram: *anyopaque = undefined,
    sceneProgram: *anyopaque = undefined,

    uTime: *anyopaque = undefined,
    uProjection: *anyopaque = undefined,
    uView: *anyopaque = undefined,

    uNear: *anyopaque = undefined,
    uFar: *anyopaque = undefined,
    uResolution: *anyopaque = undefined,

    near: f32,
    far: f32,

    colorTex: *anyopaque = undefined,
    depthTex: *anyopaque = undefined,
    fbo: *anyopaque = undefined,

    icosphere_1: RenderObject = undefined,
    icosphere_3: RenderObject = undefined,
    cube: RenderObject = undefined,

    width: i32,
    height: i32,

    pub fn create(gpa: std.mem.Allocator, width: i32, height: i32) !This {
        var this = This{
            .width = width,
            .height = height,

            .near = 0.1,
            .far = 30,
        };

        this.colorTex = gl.createTexture();
        gl.bindTexture(.TEXTURE_2D, this.colorTex);
        gl.texImage2D(.TEXTURE_2D, 0, .RGBA8, this.width, this.height, 0, .RGBA, .UNSIGNED_BYTE);
        gl.texParameteri(.TEXTURE_2D, .TEXTURE_MIN_FILTER, .NEAREST);
        gl.texParameteri(.TEXTURE_2D, .TEXTURE_MAG_FILTER, .NEAREST);

        this.depthTex = gl.createTexture();
        gl.bindTexture(.TEXTURE_2D, this.depthTex);
        gl.texImage2D(.TEXTURE_2D, 0, .DEPTH_COMPONENT24, width, height, 0, .DEPTH_COMPONENT, .UNSIGNED_INT);
        gl.texParameteri(.TEXTURE_2D, .TEXTURE_MIN_FILTER, .NEAREST);
        gl.texParameteri(.TEXTURE_2D, .TEXTURE_MAG_FILTER, .NEAREST);

        this.fbo = gl.createFrameBuffer();
        gl.bindFramebuffer(.FRAMEBUFFER, this.fbo);
        gl.framebufferTexture2D(.FRAMEBUFFER, .COLOR_ATTACHMENT0, .TEXTURE_2D, this.colorTex, 0);
        gl.framebufferTexture2D(.FRAMEBUFFER, .DEPTH_ATTACHMENT, .TEXTURE_2D, this.depthTex, 0);

        {
            this.compProgram = gl.createProgram();

            const vs = gl.createShader(gl.GLEnum_Shader.VERTEX_SHADER);
            gl.shaderSource(vs, compVertexSource);
            gl.compileShader(vs);
            gl.attachShader(this.compProgram, vs);

            const fs = gl.createShader(gl.GLEnum_Shader.FRAGMENT_SHADER);
            gl.shaderSource(fs, compFragmentSource);
            gl.compileShader(fs);
            gl.attachShader(this.compProgram, fs);

            gl.linkProgram(this.compProgram);
        }
        {
            this.sceneProgram = gl.createProgram();

            const vs = gl.createShader(gl.GLEnum_Shader.VERTEX_SHADER);
            gl.shaderSource(vs, sceneVertexSource);
            gl.compileShader(vs);
            gl.attachShader(this.sceneProgram, vs);

            const fs = gl.createShader(gl.GLEnum_Shader.FRAGMENT_SHADER);
            gl.shaderSource(fs, sceneFragmentSource);
            gl.compileShader(fs);
            gl.attachShader(this.sceneProgram, fs);

            gl.linkProgram(this.sceneProgram);
        }
        this.icosphere_1 = try RenderObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/icosphere_1.obj"), gpa),
        );
        this.icosphere_3 = try RenderObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/icosphere_3.obj"), gpa),
        );
        this.cube = try RenderObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/default_cube.obj"), gpa),
        );

        this.uProjection = gl.getUniformLocation(this.sceneProgram, "uProjection");
        this.uView = gl.getUniformLocation(this.sceneProgram, "uView");
        this.uNear = gl.getUniformLocation(this.compProgram, "uNear");
        this.uFar = gl.getUniformLocation(this.compProgram, "uFar");
        this.uResolution = gl.getUniformLocation(this.compProgram, "uResolution");

        return this;
    }

    pub fn render(this: *This, gpa: std.mem.Allocator, width: i32, height: i32) !void {
        this.width = width;
        this.height = height;
        this.t += 1;
        const f: f32 = @floatFromInt(this.t);

        var clear: i32 = 0;
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.COLOR_BUFFER_BIT);
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.DEPTH_BUFFER_BIT);
        gl.enable(.DEPTH_TEST);
        gl.enable(.CULL_FACE);
        gl.bindFramebuffer(.FRAMEBUFFER, this.fbo);

        gl.viewport(0, 0, width, height);
        gl.clear(clear);

        gl.useProgram(this.sceneProgram);

        const w = 100;
        const h = 100;

        for (0..w) |ux| {
            for (0..h) |uy| {
                var x: f32 = @floatFromInt(ux);
                x -= @floatFromInt(w / 2);
                var y: f32 = @floatFromInt(uy);
                y -= @floatFromInt(h / 2);

                var pos = m.Vec3.init(x, 0, y).mulScalar(1);
                pos.v[1] = @cos(pos.len() / 3 - f / 100) * 3 / (1 + pos.len() / 20);
                const color: m.Vec4 = .fromHsl(pos.y() / 10 + f / 1000, 1, 0.5, 1);

                const posRot = m.Mat4x4.translate(pos).mul(.rotateX(f / 100 + x / 2)).mul(.rotateZ(f / 100 - y / 2));

                try this.icosphere_1.add(gpa, posRot.mul(.scale(.init(0.7, 0.7, 0.7))), color);
            }
        }

        try this.cube.add(gpa, m.Mat4x4.translate(.init(0, -5, 0)).mul(.scale(.init(10, 1, 10))), .init(1, 1, 1, 1));

        // const uProj = m.Mat4x4.projection2D(.{ .left = -30, .right = 30, .bottom = -30, .top = 30, .near = -1200, .far = 1200 });
        const uProj = m.Mat4x4.perspective(.{ .fov = 1, .aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)), .near = this.near, .far = this.far });
        gl.uniformMatrix4fv(this.uProjection, false, uProj);

        const uView = m.Mat4x4.translate(.init(0, 0, -8))
            .mul(.rotateX(@sin(f / 500) / 3 + 0.45))
            .mul(.rotateY(f / 800));

        gl.uniformMatrix4fv(this.uView, false, uView);

        this.icosphere_1.render();
        this.icosphere_3.render();
        this.cube.render();

        // composite

        gl.bindFramebuffer(.FRAMEBUFFER, null);
        gl.viewport(0, 0, this.width, this.height);

        gl.disable(.DEPTH_TEST);
        gl.useProgram(this.compProgram);

        gl.uniform1f(this.uNear, this.near);
        gl.uniform1f(this.uFar, this.far);
        gl.uniform2f(this.uResolution, @floatFromInt(this.width), @floatFromInt(this.height));

        gl.activeTexture(.TEXTURE0);
        gl.bindTexture(.TEXTURE_2D, this.colorTex);
        gl.uniform1i(gl.getUniformLocation(this.compProgram, "uColor"), 0);

        gl.activeTexture(.TEXTURE1);
        gl.bindTexture(.TEXTURE_2D, this.depthTex);
        gl.uniform1i(gl.getUniformLocation(this.compProgram, "uDepth"), 1);

        gl.drawArrays(.TRIANGLES, 0, 3);
    }
};
