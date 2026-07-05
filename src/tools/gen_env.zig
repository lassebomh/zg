const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();

    _ = args.next(); // skip executable name
    const out_path = args.next() orelse return error.MissingOutputPath;

    var exports = std.ArrayList(FnSig).empty;
    var imports = std.ArrayList(FnSig).empty;

    defer {
        for (exports.items) |s| s.deinit(gpa);
        exports.deinit(gpa);
        for (imports.items) |s| s.deinit(gpa);
        imports.deinit(gpa);
    }
    const src_path = args.next() orelse return error.MissingSrcPath;

    var src_dir = try std.Io.Dir.openDirAbsolute(io, src_path, .{ .iterate = true });

    var walker = try src_dir.walk(gpa);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        // if (!std.mem.endsWith(u8, entry.basename, "test.zig")) continue; // MARK: Delete me

        const source = try src_dir.readFileAlloc(io, entry.path, gpa, .unlimited);
        const source_null_terminated = try gpa.dupeZ(u8, source);

        defer gpa.free(source);
        defer gpa.free(source_null_terminated);

        try extractFns(gpa, source_null_terminated, &exports, &imports);
    }

    // Sort for stable output
    const lessThan = struct {
        fn f(_: void, a: FnSig, b: FnSig) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.f;
    std.mem.sort(FnSig, exports.items, {}, lessThan);
    std.mem.sort(FnSig, imports.items, {}, lessThan);

    var out = std.ArrayList(u8).empty;
    defer out.deinit(gpa);

    try out.appendSlice(gpa,
        \\// AUTO-GENERATED
        \\
        \\export type opaque_ptr = { readonly _: unique symbol};
        \\
        \\
    );
    try emitInterface(gpa, &out, "WasmFnExports", exports.items);
    try out.appendSlice(gpa, "\n");
    try emitInterface(gpa, &out, "WasmEnv", imports.items);

    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = out_path,
        .data = out.items,
    });
}

const FnSig = struct {
    name: []const u8,
    params: []const Param,

    return_ts: []const u8,
    return_zig: []const u8,

    fn deinit(self: FnSig, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.params) |p| {
            allocator.free(p.name);
            allocator.free(p.type_zig);
        }
        allocator.free(self.params);
        allocator.free(self.return_zig);
    }
};

const Param = struct {
    name: []const u8,
    type_ts: []const u8,
    type_zig: []const u8,
};

fn extractFns(
    gpa: std.mem.Allocator,
    source: [:0]const u8,
    exports: *std.ArrayList(FnSig),
    imports: *std.ArrayList(FnSig),
) !void {
    var tree = try std.zig.Ast.parse(gpa, source, .zig);

    defer tree.deinit(gpa);
    const decls = tree.rootDecls();

    for (decls) |decl_idx| {
        var buffer: [1]std.zig.Ast.Node.Index = .{decl_idx};

        const node = tree.nodes.get(@intFromEnum(decl_idx));
        const fn_proto = switch (node.tag) {
            .fn_decl => tree.fullFnProto(&buffer, decl_idx).?,
            .fn_proto_simple => tree.fnProtoSimple(&buffer, decl_idx),
            .fn_proto_multi => tree.fnProtoMulti(decl_idx),
            .fn_proto_one => tree.fnProtoOne(&buffer, decl_idx),
            .fn_proto => tree.fnProto(decl_idx),
            else => continue,
        };

        const group = switch (tree.tokenTag((fn_proto.extern_export_inline_token orelse continue))) {
            .keyword_export => exports,
            .keyword_extern => imports,
            else => continue,
        };

        // Parse params
        var params = std.ArrayList(Param).empty;
        var param_iter = fn_proto.iterate(&tree);
        while (param_iter.next()) |param| {
            const param_name = if (param.name_token) |nt|
                try gpa.dupe(u8, tree.tokenSlice(nt))
            else
                try gpa.dupe(u8, "_");

            const param_type_node = param.type_expr;

            const type_zig: []const u8 = try gpa.dupe(u8, tree.getNodeSource(param_type_node.?));
            const type_ts: []const u8 = zigNodeTypeToTs(type_zig);

            try params.append(gpa, .{
                .name = param_name,
                .type_ts = type_ts,
                .type_zig = type_zig,
            });
        }

        const name_token = fn_proto.name_token orelse continue;
        const name = try gpa.dupe(u8, tree.tokenSlice(name_token));

        const return_zig: []const u8 = try gpa.dupe(u8, tree.getNodeSource(fn_proto.ast.return_type.unwrap().?));
        const return_ts: []const u8 = zigNodeTypeToTs(return_zig);

        const sig = FnSig{
            .name = name,
            .params = try params.toOwnedSlice(gpa),
            .return_ts = return_ts,
            .return_zig = return_zig,
        };

        try group.append(gpa, sig);
    }
}

fn zigNodeTypeToTs(source: []const u8) []const u8 {
    if (std.mem.eql(u8, source, "void")) {
        return "void";
    } else if (std.mem.eql(u8, source, "*anyopaque")) {
        return "opaque_ptr";
    } else {
        return "number";
    }
}

fn emitInterface(
    alloc: std.mem.Allocator,
    gen: *std.ArrayList(u8),
    name: []const u8,
    sigs: []const FnSig,
) !void {
    try gen.appendSlice(alloc, "export interface ");
    try gen.appendSlice(alloc, name);
    try gen.appendSlice(alloc, " {\n");

    for (sigs) |sig| {
        try gen.appendSlice(alloc, "  /**\n");
        for (sig.params) |param| {
            try gen.appendSlice(alloc, "   * @param ");
            try gen.appendSlice(alloc, param.name);
            try gen.appendSlice(alloc, " ");
            try gen.appendSlice(alloc, param.type_zig);
            try gen.appendSlice(alloc, "\n");
        }
        try gen.appendSlice(alloc, "   * @returns ");
        try gen.appendSlice(alloc, sig.return_zig);
        try gen.appendSlice(alloc, "\n");
        try gen.appendSlice(alloc, "   */\n");

        try gen.appendSlice(alloc, "  ");
        try gen.appendSlice(alloc, sig.name);
        try gen.appendSlice(alloc, "(");
        for (sig.params, 0..) |param, i| {
            if (i > 0) {
                try gen.appendSlice(alloc, ", ");
            }
            try gen.appendSlice(alloc, param.name);
            try gen.appendSlice(alloc, ": ");
            try gen.appendSlice(alloc, param.type_ts);
        }
        try gen.appendSlice(alloc, "): ");
        try gen.appendSlice(alloc, sig.return_ts);
        try gen.appendSlice(alloc, ";\n");
    }
    try gen.appendSlice(alloc, "}\n");
}
