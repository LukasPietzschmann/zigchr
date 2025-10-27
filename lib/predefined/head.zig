const lib = @import("../lib.zig");
const types = @import("../types.zig");

const Constraint = types.Constraint;
const Head = types.Head;
const SHead = types.SHead;

fn wildcard(_: Constraint, _: u32) bool {
    return true;
}
pub fn Wildcard() !Head {
    return try lib.as_head(.{ .n = undefined, .op = wildcard });
}

fn _gt(c: Constraint, n: u32) bool {
    return c.value > n;
}
pub fn gt(n: u32) SHead {
    return .{ .n = n, .op = _gt };
}
pub fn GT(n: u32) !Head {
    return try lib.as_head(gt(n));
}

fn _leq(c: Constraint, n: u32) bool {
    return c.value <= n;
}
pub fn leq(n: u32) SHead {
    return .{ .n = n, .op = _leq };
}
pub fn LEQ(n: u32) !Head {
    return try lib.as_head(leq(n));
}

fn _eq(c: Constraint, n: u32) bool {
    return c.value == n;
}
pub fn eq(n: u32) SHead {
    return .{ .n = n, .op = _eq };
}
pub fn EQ(n: u32) !Head {
    return try lib.as_head(eq(n));
}
