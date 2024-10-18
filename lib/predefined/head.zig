const types = @import("../types.zig");

const Constraint = types.Constraint;

pub fn wildcard(_: Constraint) bool {
    return true;
}

pub fn gt(n: u32) fn (Constraint) bool {
    const s = struct {
        var x: u32 = n;

        pub fn do_it(c: Constraint) bool {
            return c > n;
        }
    };
    return s.do_it;
}

pub fn leq(n: u32) fn (Constraint) bool {
    const s = struct {
        var x: u32 = n;

        pub fn do_it(c: Constraint) bool {
            return c <= n;
        }
    };
    return s.do_it;
}

pub fn eq(n: u32) fn (Constraint) bool {
    const s = struct {
        var x: u32 = n;

        pub fn do_it(c: Constraint) bool {
            return c == n;
        }
    };
    return s.do_it;
}
