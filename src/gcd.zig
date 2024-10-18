const std = @import("std");
const chr = @import("libchr");
const config = @import("config");

const solvers = chr.solvers;
const predef = chr.predefined;
const Constraint = chr.types.Constraint;

pub const std_options = .{
    .log_level = if (config.debug_logs) .debug else .info,
};

fn smaller(cs: []Constraint) bool {
    return 0 < cs[0] and cs[0] <= cs[1];
}

fn sub(cs: []Constraint) []Constraint {
    var x = [_]Constraint{cs[1] - cs[0]};
    return &x;
}

pub fn main() !void {
    defer chr.deinit();

    // zero @ gcd(0) <=> true.
    // sub  @ gcd(N) \ gcd(M) <=> N>0, M>0, N=<M | gcd(M-N)

    var solver: solvers.RuleSolver = .{ .name = "zero", .kh = try chr.emptyHead(), .rh = try chr.as_head(predef.head.eq(0)), .g = predef.guard.always, .b = predef.body.top };
    var solver2: solvers.RuleSolver = .{ .name = "sub", .kh = try chr.as_head(predef.head.gt(0)), .rh = try chr.as_head(predef.head.gt(0)), .g = smaller, .b = sub };

    var compositeGen: solvers.CompositeSolver = .{};
    try compositeGen.own(solver.init());
    try compositeGen.own(solver2.init());

    var elements = [_]Constraint{ 94017, 1155, 2035 };
    var state = try solvers.runSolver(compositeGen.init(), &elements);
    defer state.deinit();
    defer compositeGen.deinit();

    // =============================================================

    std.log.info("Remaining constraints in the store:", .{});
    var it = state.store.valueIterator();
    while (it.next()) |constraint| {
        std.log.info("{d}", .{constraint.*});
    }
}
