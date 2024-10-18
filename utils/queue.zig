const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        backing: std.ArrayList(T),

        pub fn init(allocator: std.mem.Allocator) Queue(T) {
            return .{
                .backing = std.ArrayList(T).init(allocator),
            };
        }

        pub fn deinit(self: *Queue(T)) void {
            self.backing.deinit();
            self.* = undefined;
        }

        pub fn empty(self: Queue(T)) bool {
            return self.backing.items.len == 0;
        }

        pub fn push(self: *Queue(T), elem: T) !void {
            try self.backing.append(elem);
        }

        pub fn pop(self: *Queue(T)) ?T {
            if (self.empty()) {
                return null;
            }
            return self.backing.pop();
        }
    };
}
