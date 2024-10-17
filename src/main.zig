const std = @import("std");
const lib = @import("root.zig");

pub const std_options = .{
    .log_level = .info,
};

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
    // min(X) \ min(Y) <=> X <= Y | true

    const kh = try lib.toHead(truefn);
    const rh = try lib.toHead(truefn);
    defer {
        kh.deinit();
        rh.deinit();
        lib.deinit();
    }

    var solverGen: lib.RuleSolver = .{ .name = "min", .kh = kh, .rh = rh, .g = smaller, .b = top };
    const solver = solverGen.init();
    var elements = [_]u32{ 4, 45 };
    var state = try lib.runSolver(solver, &elements);
    defer state.deinit();
    var it = state.store.valueIterator();
    std.log.info("Remaining constraints in the store:", .{});
    while (it.next()) |constraint| {
        std.log.info("{d}", .{constraint.*});
    }
}
