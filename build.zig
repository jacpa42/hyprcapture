const std = @import("std");
const zon = @import("./build.zig.zon");

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

    addDependencies(b, exe.root_module, target, optimize);
    addRunStep(b, exe);

    const release = b.step("release", "Create release builds of hyprcapture");
    const git_version = getGitVersion(b);
    if (git_version == .tag) {
        if (std.mem.eql(u8, zon.version, git_version.tag[1..])) {
            setupReleaseStep(b, release);
        } else {
            release.dependOn(&b.addFail(b.fmt(
                "git tag does not match zon package version (zon: '{s}', git: '{s}')",
                .{ zon.version, git_version.tag[1..] },
            )).step);
        }
    } else {
        release.dependOn(&b.addFail(
            "git tag missing, cannot make release builds",
        ).step);
    }
}

fn addDependencies(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    module.addImport("sqlite", sqlite.module("sqlite"));
}

fn addRunStep(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
) void {
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}

fn setupTestStep(
    b: *std.Build,
    hyprcapture: *std.Build.Module,
) void {
    const test_step = b.step("test", "Run unit tests");

    const unit_tests = b.addTest(.{
        .root_module = hyprcapture,
        .filters = b.args orelse &.{},
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}

fn setupReleaseStep(
    b: *std.Build,
    release_step: *std.Build.Step,
) void {
    const targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl },
    };

    for (targets) |t| {
        const target = b.resolveTargetQuery(t);
        const optimize = std.builtin.OptimizeMode.ReleaseFast;
        const root_module = b.createModule(.{
            .root_source_file = b.path("hyprcapture.zig"),
            .target = target,
            .optimize = optimize,
        });
        addDependencies(b, root_module, target, optimize);

        const exe_release = b.addExecutable(.{
            .name = "hyprcapture",
            .root_module = root_module,
        });

        switch (t.os_tag.?) {
            .macos, .windows => {
                const archive_name = b.fmt("{s}.zip", .{
                    t.zigTriple(b.allocator) catch unreachable,
                });

                const zip = b.addSystemCommand(&.{
                    "zip",
                    "-9",
                    // "-dd",
                    "-q",
                    "-j",
                });
                const archive = zip.addOutputFileArg(archive_name);
                zip.addDirectoryArg(exe_release.getEmittedBin());
                _ = zip.captureStdOut();

                release_step.dependOn(&b.addInstallFileWithDir(
                    archive,
                    .{ .custom = "releases" },
                    archive_name,
                ).step);
            },
            else => {
                const archive_name = b.fmt("{s}.tar.xz", .{
                    t.zigTriple(b.allocator) catch unreachable,
                });

                const tar = b.addSystemCommand(&.{
                    "tar",
                    "-cJf",
                });

                const archive = tar.addOutputFileArg(archive_name);
                tar.addArg("-C");

                tar.addDirectoryArg(exe_release.getEmittedBinDirectory());
                tar.addArg("hyprcapture");
                _ = tar.captureStdOut();

                release_step.dependOn(&b.addInstallFileWithDir(
                    archive,
                    .{ .custom = "releases" },
                    archive_name,
                ).step);
            },
        }
    }
}

const Version = union(Kind) {
    tag: []const u8,
    commit: []const u8,
    // not in a git repo
    unknown,

    pub const Kind = enum { tag, commit, unknown };

    pub fn string(v: Version) []const u8 {
        return switch (v) {
            .tag, .commit => |tc| tc,
            .unknown => "unknown",
        };
    }
};

fn getGitVersion(b: *std.Build) Version {
    const git_path = b.findProgram(&.{"git"}, &.{}) catch return .unknown;
    var out: u8 = undefined;
    const git_describe = std.mem.trim(
        u8,
        b.runAllowFail(&[_][]const u8{
            git_path,            "-C",
            b.build_root.path.?, "describe",
            "--match",           "*.*.*",
            "--tags",
        }, &out, .Ignore) catch return .unknown,
        " \n\r",
    );

    switch (std.mem.count(u8, git_describe, "-")) {
        0 => return .{ .tag = git_describe },
        2 => {
            // Untagged development build (e.g. 0.8.0-684-gbbe2cca1a).
            var it = std.mem.splitScalar(u8, git_describe, '-');
            const tagged_ancestor = it.next() orelse unreachable;
            const commit_height = it.next() orelse unreachable;
            const commit_id = it.next() orelse unreachable;

            // Check that the commit hash is prefixed with a 'g'
            // (it's a Git convention)
            if (commit_id.len < 1 or commit_id[0] != 'g') {
                std.debug.panic("Unexpected `git describe` output: {s}\n", .{git_describe});
            }

            // The version is reformatted in accordance with
            // the https://semver.org specification.
            return .{
                .commit = b.fmt("{s}-dev.{s}+{s}", .{
                    tagged_ancestor,
                    commit_height,
                    commit_id[1..],
                }),
            };
        },
        else => std.debug.panic(
            "Unexpected `git describe` output: {s}\n",
            .{git_describe},
        ),
    }
}
