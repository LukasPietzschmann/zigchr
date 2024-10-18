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

fn smaller2(cs: []Constraint) bool {
    return 0 < cs[0] and cs[0] <= cs[1];
}

fn sub(cs: []Constraint) []Constraint {
    var x = [_]Constraint{cs[1] - cs[0]};
    return &x;
}

pub fn main() !void {
    defer chr.deinit();

    // min(X) \ min(Y) <=> X <= Y | true

    var solver: solvers.RuleSolver = .{ .name = "min", .kh = try chr.as_head(predef.head.wildcard), .rh = try chr.as_head(predef.head.wildcard), .g = smaller, .b = predef.body.top };
    defer solver.deinit();

    var elements = [_]Constraint{ 4, 45 };
    var state = try solvers.runSolver(solver.init(), &elements);

    // =============================================================

    // zero @ gcd(0) <=> true.
    // sub  @ gcd(N) \ gcd(M) <=> N>0, M>0, N=<M | gcd(M-N)

    // var solver: solvers.RuleSolver = .{ .name = "zero", .kh = try chr.emptyHead(), .rh = try chr.as_head(predef.head.eq(0)), .g = predef.guard.always, .b = predef.body.top };
    // var solver2: solvers.RuleSolver = .{ .name = "sub", .kh = try chr.as_head(predef.head.gt(0)), .rh = try chr.as_head(predef.head.gt(0)), .g = smaller2, .b = sub };

    // var compositeGen: solvers.CompositeSolver = .{};
    // try compositeGen.own(solver.init());
    // try compositeGen.own(solver2.init());

    // var elements = [_]Constraint{ 1, 99787 };
    // var state = try solvers.runSolver(compositeGen.init(), &elements);
    // defer compositeGen.deinit();

    defer state.deinit();

    // =============================================================

    std.log.info("Remaining constraints in the store:", .{});
    var it = state.store.valueIterator();
    while (it.next()) |constraint| {
        std.log.info("{d}", .{constraint.*});
    }
}
