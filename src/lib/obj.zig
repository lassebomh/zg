const std = @import("std");

const debug = @import("../js/debug.zig");
const m = @import("../math/main.zig");

const ObjLineType = enum {
    const This = @This();

    comment,
    material,
    object,
    vertex,
    normal,
    texture,
    face,
    smooth,
    line,
    use_material,

    fn fromText(text: []const u8) !ObjLineType {
        if (std.mem.eql(u8, text, "#")) {
            return This.comment;
        } else if (std.mem.eql(u8, text, "mtllib")) {
            return This.material;
        } else if (std.mem.eql(u8, text, "v")) {
            return This.vertex;
        } else if (std.mem.eql(u8, text, "vt")) {
            return This.texture;
        } else if (std.mem.eql(u8, text, "vn")) {
            return This.normal;
        } else if (std.mem.eql(u8, text, "f")) {
            return This.face;
        } else if (std.mem.eql(u8, text, "o")) {
            return This.object;
        } else if (std.mem.eql(u8, text, "s")) {
            return This.smooth;
        } else if (std.mem.eql(u8, text, "usemtl")) {
            return This.use_material;
        } else {
            return error.UnknownObjLine;
        }
    }
};

pub const Face = struct {
    vertex_idxs: [3]u32,
    texture_idxs: [3]u32,
    normal_idxs: [3]u32,
};

pub const ObjMesh = struct {
    verts: []f32,
    normals: []f32,
    uvs: []f32,

    face_vert_idxs: []u32,
    face_normal_idxs: []u32,
    face_uv_idxs: []u32,

    pub fn fromFile(
        content: []const u8,
        gpa: std.mem.Allocator,
    ) !ObjMesh {
        var lines = std.mem.splitScalar(u8, content, '\n');

        var verts: std.ArrayList(f32) = .empty;
        var normals: std.ArrayList(f32) = .empty;
        var uvs: std.ArrayList(f32) = .empty;

        var face_vert_idxs: std.ArrayList(u32) = .empty;
        var face_normal_idxs: std.ArrayList(u32) = .empty;
        var face_uv_idxs: std.ArrayList(u32) = .empty;

        while ((&lines).next()) |line| {
            var parts = std.mem.splitScalar(u8, line, ' ');

            const line_type_text = (&parts).next() orelse return error.EmptyLine;
            if (line_type_text.len == 0) continue;

            const line_type = try ObjLineType.fromText(line_type_text);

            switch (line_type) {
                .comment => continue,
                .object => continue,
                .material => continue,
                .smooth => continue,
                .line => continue,
                .use_material => continue,

                .vertex => {
                    const vert = try (&verts).addManyAsArray(gpa, 3);
                    vert[0] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidVertex);
                    vert[1] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidVertex);
                    vert[2] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidVertex);
                },
                .normal => {
                    const norm = try (&normals).addManyAsArray(gpa, 3);
                    norm[0] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidNormal);
                    norm[1] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidNormal);
                    norm[2] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidNormal);
                },
                .texture => {
                    const tex = try (&uvs).addManyAsArray(gpa, 2);
                    tex[0] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidUV);
                    tex[1] = try std.fmt.parseFloat(f32, (&parts).next() orelse return error.InvalidUV);
                },
                .face => {
                    var face_verts: [4]u32 = undefined;
                    var face_norms: [4]u32 = undefined;
                    var face_texs: [4]u32 = undefined;
                    var vert_count: u32 = 0;

                    while (vert_count < 4) : (vert_count += 1) {
                        const idxs = (&parts).next() orelse break;
                        var idx_parts = std.mem.splitScalar(u8, idxs, '/');
                        face_verts[vert_count] = try std.fmt.parseInt(u32, (&idx_parts).next() orelse return error.InvalidVertexIndex, 10) - 1;
                        face_texs[vert_count] = try std.fmt.parseInt(u32, (&idx_parts).next() orelse return error.InvalidTextureIndex, 10) - 1;
                        face_norms[vert_count] = try std.fmt.parseInt(u32, (&idx_parts).next() orelse return error.InvalidNormalIndex, 10) - 1;
                    }
                    if (vert_count < 3) return error.MissingIndicies;

                    const tris: []const [3]u32 = if (vert_count == 4) &.{ .{ 0, 1, 2 }, .{ 0, 2, 3 } } else &.{.{ 0, 1, 2 }};
                    for (tris) |tri| {
                        for (tri) |i| {
                            (try (&face_vert_idxs).addOne(gpa)).* = face_verts[i];
                            (try (&face_normal_idxs).addOne(gpa)).* = face_norms[i];
                            (try (&face_uv_idxs).addOne(gpa)).* = face_texs[i];
                        }
                    }
                },
            }
        }

        return .{
            .verts = verts.items,
            .uvs = uvs.items,
            .normals = normals.items,

            .face_vert_idxs = face_vert_idxs.items,
            .face_normal_idxs = face_normal_idxs.items,
            .face_uv_idxs = face_uv_idxs.items,
        };
    }
};
