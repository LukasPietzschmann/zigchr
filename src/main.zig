const std = @import("std");
const lib = @import("root.zig");

pub fn main() !void {
    std.debug.print("All your {s} are belongs to us.\n", .{"codebase"});
}
