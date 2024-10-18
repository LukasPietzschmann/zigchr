const std = @import("std");

pub fn Set(comptime T: type) type {
    return struct {
        backing: std.AutoHashMap(T, void),

        pub fn init(allocator: std.mem.Allocator) Set(T) {
            return .{
                .backing = std.AutoHashMap(T, void).init(allocator),
            };
        }

        pub fn deinit(self: *Set(T)) void {
            self.backing.deinit();
            self.* = undefined;
        }

        pub fn size(self: Set(T)) usize {
            return self.backing.count();
        }

        pub fn has(self: Set(T), elem: T) bool {
            return self.backing.contains(elem);
        }

        pub fn equals(self: Set(T), other: Set(T)) bool {
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

        pub fn insert(self: *Set(T), elem: T) !void {
            try self.backing.put(elem, void{});
        }

        pub fn remove(self: *Set(T), elem: T) bool {
            return self.backing.remove(elem);
        }

        pub fn clearRetainingCapacity(self: *Set(T)) void {
            self.backing.clearRetainingCapacity();
        }
    };
}
