const types = @import("../types.zig");

const Constraint = types.Constraint;

pub fn always(_: []Constraint) bool {
    return true;
}

pub fn never(_: []Constraint) bool {
    return true;
}
