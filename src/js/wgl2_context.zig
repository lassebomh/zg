const std = @import("std");

const gl = @import("../js/wgl2.zig");
const ObjMesh = @import("../lib/obj.zig").ObjMesh;
const m = @import("../math/main.zig");

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
    \\uniform vec2 uResolution;
    \\
    \\#define COLOR_QUANTIZATION 5.0
    \\#define EDGE_STRENGTH 1.0
    \\
    \\in vec2 vUV;
    \\out vec4 fragColor;
    \\
    \\float bayer4x4Threshold(vec2 pos) {
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
    \\  float threshold = bayer4x4Threshold(fragCoord);
    \\  vec3 stepped = color * (levels - 1.0) + (threshold - 0.5);
    \\  return floor(clamp(stepped, 0.0, levels - 1.0) + 0.5) / (levels - 1.0);
    \\}
    \\float getDepth(int offsetX, int offsetY) {
    \\  vec2 invRes = 1.0 / uResolution;
    \\  float depth = texture(uDepth, vUV + vec2(offsetX, offsetY) * invRes).r;
    \\  return depth;
    \\}
    \\
    \\float depthEdgeIndicator(float depth) {
    \\  float diff = 0.0;
    \\  diff += clamp(getDepth( 1, 0) - depth, 0.0, 1.0);
    \\  diff += clamp(getDepth(-1, 0) - depth, 0.0, 1.0);
    \\  diff += clamp(getDepth( 0,-1) - depth, 0.0, 1.0);
    \\  diff += clamp(getDepth( 0, 1) - depth, 0.0, 1.0);
    \\  // diff += clamp(getDepth( 1, 1) - depth, 0.0, 1.0);
    \\  // diff += clamp(getDepth(-1, -1) - depth, 0.0, 1.0);
    \\  // diff += clamp(getDepth( 1, -1) - depth, 0.0, 1.0);
    \\  // diff += clamp(getDepth(-1, 1) - depth, 0.0, 1.0);
    \\
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
pub const GLObject = struct {
    const This = @This();

    vao: *anyopaque,

    aModels: *anyopaque,
    aNormalModels: *anyopaque,
    aColors: *anyopaque,

    normalModels: std.ArrayList(m.Mat4x4) = .empty,
    models: std.ArrayList(m.Mat4x4) = .empty,
    colors: std.ArrayList(m.Vec4) = .empty,

    elements: i32 = 0,

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

    pub fn init(gpa: std.mem.Allocator, program: *anyopaque, obj: ObjMesh) !GLObject {
        var this = This{
            .vao = gl.createVertexArray(),
            .aModels = gl.createBuffer(),
            .aNormalModels = gl.createBuffer(),
            .aColors = gl.createBuffer(),
        };
        gl.bindVertexArray(this.vao);

        // construct the attribute data.

        var idxs: std.ArrayList(u32) = .empty;
        var data: std.ArrayList(f32) = .empty;

        var hashmap: std.AutoHashMap([6]u32, u32) = .init(gpa);
        defer hashmap.deinit();

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

        // this.elements = idxs.len;

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

pub const GLCamera = struct {
    view: m.Mat4x4,
    projection: m.Mat4x4,
    screen: m.Vec2,
};

pub const GLContext = struct {
    const This = @This();

    compProgram: *anyopaque = undefined,
    sceneProgram: *anyopaque = undefined,

    uTime: *anyopaque = undefined,
    uProjection: *anyopaque = undefined,
    uView: *anyopaque = undefined,

    uResolution: *anyopaque = undefined, // for comp

    colorTex: *anyopaque = undefined,
    depthTex: *anyopaque = undefined,
    fbo: *anyopaque = undefined,

    icosphere_1: GLObject = undefined,
    icosphere_3: GLObject = undefined,
    cube: GLObject = undefined,
    cylinder: GLObject = undefined,

    screen: m.Vec2,

    pub fn create(gpa: std.mem.Allocator) !This {
        var this = This{
            .screen = .init(1, 1),
        };

        this.colorTex = gl.createTexture();
        gl.bindTexture(.TEXTURE_2D, this.colorTex);
        gl.texImage2D(.TEXTURE_2D, 0, .RGBA8, @intFromFloat(this.screen.x()), @intFromFloat(this.screen.y()), 0, .RGBA, .UNSIGNED_BYTE);
        gl.texParameteri(.TEXTURE_2D, .TEXTURE_MIN_FILTER, .NEAREST);
        gl.texParameteri(.TEXTURE_2D, .TEXTURE_MAG_FILTER, .NEAREST);

        this.depthTex = gl.createTexture();
        gl.bindTexture(.TEXTURE_2D, this.depthTex);
        gl.texImage2D(.TEXTURE_2D, 0, .DEPTH_COMPONENT24, @intFromFloat(this.screen.x()), @intFromFloat(this.screen.y()), 0, .DEPTH_COMPONENT, .UNSIGNED_INT);
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
        this.icosphere_1 = try GLObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/icosphere_1.obj"), gpa),
        );
        this.icosphere_3 = try GLObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/icosphere_3.obj"), gpa),
        );
        this.cube = try GLObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/default_cube.obj"), gpa),
        );
        this.cylinder = try GLObject.init(
            gpa,
            this.sceneProgram,
            try ObjMesh.fromFile(@embedFile("../models/cylinder.obj"), gpa),
        );

        this.uProjection = gl.getUniformLocation(this.sceneProgram, "uProjection");
        this.uView = gl.getUniformLocation(this.sceneProgram, "uView");
        this.uResolution = gl.getUniformLocation(this.compProgram, "uResolution");

        return this;
    }

    pub fn render(this: *This, camera: GLCamera) !void {
        if (!this.screen.eql(&camera.screen)) {
            this.screen = camera.screen;
            gl.bindTexture(.TEXTURE_2D, this.colorTex);
            gl.texImage2D(.TEXTURE_2D, 0, .RGBA8, @intFromFloat(this.screen.x()), @intFromFloat(this.screen.y()), 0, .RGBA, .UNSIGNED_BYTE);
            gl.bindTexture(.TEXTURE_2D, this.depthTex);
            gl.texImage2D(.TEXTURE_2D, 0, .DEPTH_COMPONENT24, @intFromFloat(this.screen.x()), @intFromFloat(this.screen.y()), 0, .DEPTH_COMPONENT, .UNSIGNED_INT);
        }

        var clear: i32 = 0;
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.COLOR_BUFFER_BIT);
        clear |= @intFromEnum(gl.GLEnum_ClearBuffer.DEPTH_BUFFER_BIT);
        gl.enable(.DEPTH_TEST);
        gl.enable(.CULL_FACE);
        gl.bindFramebuffer(.FRAMEBUFFER, this.fbo);

        gl.viewport(0, 0, @intFromFloat(camera.screen.x()), @intFromFloat(camera.screen.y()));
        gl.clear(clear);

        gl.useProgram(this.sceneProgram);

        // const uProj = m.Mat4x4.projection2D(.{ .left = -6 * aspectRatio, .right = 6 * aspectRatio, .bottom = -6, .top = 6, .near = 0.01, .far = 25 });
        gl.uniformMatrix4fv(this.uProjection, false, camera.projection);

        // const uView = m.Mat4x4.translate(.init(0, 0, -10))
        //     .mul(.rotateX(@sin(f / 500) / 4 + 0.6))
        //     .mul(.rotateY(f / 800));

        // const uView = m.Mat4x4.translate(.init(0, 0, -8))
        //     .mul(.rotateX(0.05))
        //     .mul(.rotateY(0));

        gl.uniformMatrix4fv(this.uView, false, camera.view);

        this.icosphere_1.render();
        this.icosphere_3.render();
        this.cube.render();
        this.cylinder.render();

        // composite
        gl.bindFramebuffer(.FRAMEBUFFER, null);

        gl.disable(.DEPTH_TEST);
        gl.useProgram(this.compProgram);
        gl.viewport(0, 0, @intFromFloat(camera.screen.x()), @intFromFloat(camera.screen.y()));

        gl.uniform2f(this.uResolution, camera.screen.x(), camera.screen.y());

        gl.activeTexture(.TEXTURE0);
        gl.bindTexture(.TEXTURE_2D, this.colorTex);
        gl.uniform1i(gl.getUniformLocation(this.compProgram, "uColor"), 0);

        gl.activeTexture(.TEXTURE1);
        gl.bindTexture(.TEXTURE_2D, this.depthTex);
        gl.uniform1i(gl.getUniformLocation(this.compProgram, "uDepth"), 1);

        gl.drawArrays(.TRIANGLES, 0, 3);
    }
};
