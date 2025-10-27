const std = @import("std");
const config = @import("config");

pub fn debug(comptime format: []const u8, args: anytype) void {
    if (!config.debug_logs) {
        return;
    }
    std.log.info(format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    std.log.info(format, args);
}
