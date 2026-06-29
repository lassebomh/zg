const std = @import("std");

pub fn build(b: *std.Build) void {
    const mod = b.createModule(.{
        .root_source_file = b.path("src/wasm.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
    });

    const app = b.addExecutable(.{
        .name = "main",
        .root_module = mod,
    });
    app.entry = .disabled;
    app.rdynamic = true;

    const install_wasm = b.addInstallArtifact(app, .{
        .dest_dir = .{ .override = .{ .custom = "../frontend/src/wasm" } },
    });

    b.getInstallStep().dependOn(&install_wasm.step);

    // Generate TypeScript bindings for Zig structs shared with the frontend.
    const gen_mod = b.createModule(.{
        .root_source_file = b.path("src/tools/gen_ts.zig"),
        .target = b.graph.host,
    });
    gen_mod.addImport("app", b.createModule(.{
        .root_source_file = b.path("src/bindgen.zig"),
    }));
    const gen_exe = b.addExecutable(.{
        .name = "gen_ts",
        .root_module = gen_mod,
    });

    const run_gen = b.addRunArtifact(gen_exe);
    const bindings_ts = run_gen.addOutputFileArg("bindings.ts");

    const install_bindings = b.addInstallFile(bindings_ts, "../frontend/src/generated/bindings.ts");
    b.getInstallStep().dependOn(&install_bindings.step);
}
