const types = @import("../types.zig");

const Constraint = types.Constraint;

pub fn top(_: []Constraint) []Constraint {
    return &[_]Constraint{};
}
