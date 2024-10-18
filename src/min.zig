const std = @import("std");
const chr = @import("libchr");

const solvers = chr.solvers;
const predef = chr.predefined;
const Constraint = chr.types.Constraint;

fn smaller(cs: []Constraint) bool {
    return cs[0].value <= cs[1].value;
}

pub fn main() !void {
    defer chr.deinit();

    // min(X) \ min(Y) <=> X <= Y | true

    var solver = solvers.simpagation("min", try predef.head.Wildcard(), try predef.head.Wildcard(), smaller, predef.body.top);
    defer solver.deinit();

    const query = try chr.argv_to_query(null);
    defer chr.allocator.free(query);

    var state = try solvers.runSolver(solver.init(), query);
    defer state.deinit();

    chr.log.info("Remaining constraints in the store:", .{});
    var it = state.store.valueIterator();
    while (it.next()) |constraint| {
        chr.log.info("{d}", .{constraint.*});
    }
}
