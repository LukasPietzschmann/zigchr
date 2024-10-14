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

    var fs = [_]lib.SHead{truefn};
    var solverGen: lib.RuleSolver = .{ .name = "test", .kh = &fs, .rh = &fs, .g = smaller, .b = top };
    const solver = solverGen.init();
    var elements = [_]u32{ 1, 2, 3, 4 };
    _ = lib.runSolver(solver, &elements, null);
}
