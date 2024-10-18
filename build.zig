const std = @import("std");

pub fn build(b: *std.Build) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    defer arena.deinit();

    const show_debug_logs = b.option(bool, "log", "Show detailed execution logs") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "debug_logs", show_debug_logs);

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

    const path_to_src = try std.fs.cwd().realpathAlloc(alloc, "src");
    const src_dir = try std.fs.openDirAbsolute(path_to_src, .{
        .iterate = true,
    });

    var it = src_dir.iterate();
    while (try it.next()) |file| {
        const path = try std.fs.path.join(alloc, &[_][]const u8{ "src", file.name });
        const name = std.fs.path.stem(file.name);

        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("utils", utils);
        exe.root_module.addImport("libchr", lib_chr);
        exe.root_module.addOptions("config", options);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step(name, "Run the example");
        run_step.dependOn(&run_cmd.step);
    }
}
