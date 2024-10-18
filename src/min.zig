const std = @import("std");
const chr = @import("libchr");

const solvers = chr.solvers;
const predef = chr.predefined;
const Constraint = chr.types.Constraint;

pub const std_options = .{
    .log_level = .debug,
};

fn smaller(cs: []Constraint) bool {
    return cs[0] < cs[1];
}

pub fn main() !void {
    defer chr.deinit();

    // min(X) \ min(Y) <=> X <= Y | true

    var solver: solvers.RuleSolver = .{ .name = "min", .kh = try chr.as_head(predef.head.wildcard), .rh = try chr.as_head(predef.head.wildcard), .g = smaller, .b = predef.body.top };
    defer solver.deinit();

    var elements = [_]Constraint{ 4, 45 };
    var state = try solvers.runSolver(solver.init(), &elements);
    defer state.deinit();

    std.log.info("Remaining constraints in the store:", .{});
    var it = state.store.valueIterator();
    while (it.next()) |constraint| {
        std.log.info("{d}", .{constraint.*});
    }
}
