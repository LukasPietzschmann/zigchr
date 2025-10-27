const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Set(comptime T: type) type {
    return struct {
        backing: std.AutoHashMapUnmanaged(T, void) = .empty,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: Allocator) void {
            self.backing.deinit(allocator);
            self.* = undefined;
        }

        pub fn size(self: Self) usize {
            return self.backing.count();
        }

        pub fn has(self: Self, elem: T) bool {
            return self.backing.contains(elem);
        }

        pub fn equals(self: Self, other: Self) bool {
            if (self.size() != other.size()) {
                return false;
            }
            var it = self.backing.keyIterator();
            while (it.next()) |elem| {
                if (!other.has(elem.*)) {
                    return false;
                }
            }
            return true;
        }

        pub fn insert(self: *Self, allocator: Allocator, elem: T) !void {
            try self.backing.put(allocator, elem, {});
        }

        pub fn remove(self: *Self, elem: T) bool {
            return self.backing.remove(elem);
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.backing.clearRetainingCapacity();
        }
    };
}
