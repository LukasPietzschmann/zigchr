const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("utils/utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_chr = b.addModule("libchr", .{
        .root_source_file = b.path("lib/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_chr.addImport("utils", utils);

    const exe = b.addExecutable(.{
        .name = "zigchr",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("utils", utils);
    exe.root_module.addImport("libchr", lib_chr);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run zigchr");
    run_step.dependOn(&run_cmd.step);
}
