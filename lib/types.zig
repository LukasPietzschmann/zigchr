const std = @import("std");

pub const List = std.ArrayList;
pub const ID = u32;
pub const SHead = *const fn (Constraint) bool;
pub const Head = List(SHead);
pub const Guard = *const fn ([]Constraint) bool;
pub const Body = *const fn ([]Constraint) []Constraint;
pub const String = []const u8;
pub const Tag = u8;
pub const Value = u32;

pub const Constraint = struct {
    pub const default_tag: Tag = 0;

    value: Value,
    tag: Tag = default_tag,

    pub fn format(self: Constraint, comptime fmt: String, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}({d})", .{ self.tag, self.value });
    }
};

pub const Active = struct {
    id: ID,
    constraint: Constraint,

    pub fn format(self: Active, comptime fmt: String, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}", .{self.constraint});
    }
};
