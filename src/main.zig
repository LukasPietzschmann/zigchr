const std = @import("std");
const lib = @import("root.zig");

fn truefn(_: u32) bool {
    return true;
}

fn smaller(cs: []u32) bool {
    return cs[0] <= cs[1];
}

fn top(_: []u32) []u32 {
    return &[_]u32{};
}

pub fn main() !void {
    std.debug.print("All your {s} are belongs to us.\n", .{"codebase"});

    // min(X) \ min(Y) <=> X <= Y | true

    const kh = lib.toHead(truefn);
    const rh = lib.toHead(truefn);
    defer {
        kh.deinit();
        rh.deinit();
    }

    var solverGen: lib.RuleSolver = .{ .name = "test", .kh = kh, .rh = rh, .g = smaller, .b = top };
    const solver = solverGen.init();
    var elements = [_]u32{ 100, 8, 2, 3, 4 };
    const state = lib.runSolver(solver, &elements, null);
    var it = state.store.valueIterator();
    while (it.next()) |constraint| {
        std.log.info("{d}", .{constraint.*});
    }
}
