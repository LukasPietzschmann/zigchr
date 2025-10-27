const std = @import("std");
const config = @import("config");

pub const List = std.ArrayList;
pub const ID = u32;
pub const SHead = struct {
    n: u32,
    op: *const fn (c: Constraint, n: u32) bool,
};
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

    pub fn format(self: Constraint, writer: *std.Io.Writer) !void {
        if (config.no_show_tag) {
            try writer.print("{d}", .{self.value});
        } else {
            try writer.print("{d}({d})", .{ self.tag, self.value });
        }
    }
};

pub const Active = struct {
    id: ID,
    constraint: Constraint,

    pub fn format(self: Active, writer: *std.Io.Writer) !void {
        try writer.print("{f}", .{self.constraint});
    }

    pub const FmtSlices = struct {
        slices: []const []const Active,
        pub fn format(self: FmtSlices, w: *std.Io.Writer) !void {
            try w.writeAll("{ ");
            for (self.slices, 0..) |ms, i| {
                if (i != 0) try w.writeAll(", ");
                try w.print("{f}", .{FmtSlice{ .slice = ms }});
            }
            try w.writeAll(" }");
        }
    };

    pub const FmtSlice = struct {
        slice: []const Active,
        pub fn format(self: FmtSlice, w: *std.Io.Writer) !void {
            try w.writeAll("{ ");
            for (self.slice, 0..) |m, i| {
                if (i != 0) try w.writeAll(", ");
                try w.print("{f}", .{m});
            }
            try w.writeAll(" }");
        }
    };
};
