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
    return cs[0] < cs[1];
}

pub fn main() !void {
    defer chr.deinit();

    // min(X) \ min(Y) <=> X <= Y | true

    var solver = solvers.simpagation("min", try chr.as_head(predef.head.wildcard), try chr.as_head(predef.head.wildcard), smaller, predef.body.top);
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
