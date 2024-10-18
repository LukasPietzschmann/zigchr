const lib = @import("../lib.zig");
const types = @import("../types.zig");

const Constraint = types.Constraint;
const Head = types.Head;

pub fn wildcard(_: Constraint) bool {
    return true;
}
pub inline fn Wildcard() !Head {
    return try lib.as_head(wildcard);
}

pub fn gt(n: u32) fn (Constraint) bool {
    const s = struct {
        var x: u32 = n;

        pub fn do_it(c: Constraint) bool {
            return c.value > n;
        }
    };
    return s.do_it;
}
pub inline fn GT(n: u32) !Head {
    return try lib.as_head(gt(n));
}

pub fn leq(n: u32) fn (Constraint) bool {
    const s = struct {
        var x: u32 = n;

        pub fn do_it(c: Constraint) bool {
            return c.value <= n;
        }
    };
    return s.do_it;
}
pub inline fn LEQ(n: u32) !Head {
    return try lib.as_head(leq(n));
}

pub fn eq(n: u32) fn (Constraint) bool {
    const s = struct {
        var x: u32 = n;

        pub fn do_it(c: Constraint) bool {
            return c.value == n;
        }
    };
    return s.do_it;
}
pub inline fn EQ(n: u32) !Head {
    return try lib.as_head(eq(n));
}
