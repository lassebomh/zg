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
        .dest_dir = .{ .override = .{ .custom = "../frontend/public" } },
    });

    b.getInstallStep().dependOn(&install_wasm.step);
}
