const std = @import("std");

pub fn build(b: *std.Build) !void {
    const show_debug_logs = b.option(bool, "log", "Show detailed execution logs") orelse false;
    const no_show_tag = b.option(bool, "notag", "When logging, don't show the tag of the constraint") orelse false;
    const show_matchings = b.option(bool, "matchings", "Show all possible matchings") orelse false;
    const show_store = b.option(bool, "store", "Show the constraint store after each alteration") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "debug_logs", show_debug_logs);
    options.addOption(bool, "no_show_tag", no_show_tag);
    options.addOption(bool, "show_matchings", show_matchings);
    options.addOption(bool, "show_store", show_store);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const utils = b.createModule(.{
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
    lib_chr.addOptions("config", options);

    const path_to_src = try std.fs.cwd().realpathAlloc(b.allocator, "src");
    const src_dir = try std.fs.openDirAbsolute(path_to_src, .{
        .iterate = true,
    });

    var it = src_dir.iterate();
    while (try it.next()) |file| {
        const path = b.pathJoin(&.{ "src", file.name });
        const name = std.fs.path.stem(file.name);

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("utils", utils);
        exe.root_module.addImport("libchr", lib_chr);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step(name, b.fmt("Run the {s} example", .{name}));
        run_step.dependOn(&run_cmd.step);
    }
}
