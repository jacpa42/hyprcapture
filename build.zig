const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hyprcapture",
        .use_llvm = optimize == .Debug,
        .root_module = b.createModule(.{
            .root_source_file = b.path("hyprcapture.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize != .Debug,
        }),
    });
    b.installArtifact(exe);

    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);
}
