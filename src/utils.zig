const std = @import("std");

fn Set(comptime T: type) type {
    return struct {
        backing: std.AutoHashMap(T, void) = .{},

        pub fn has(self: *Set(T), elem: T) bool {
            return self.backing.contains(elem);
        }

        pub fn insert(self: *Set(T), elem: T) bool {
            return self.backing.put(elem, void{});
        }

        pub fn remove(self: *Set(T), elem: T) bool {
            return self.backing.remove(elem);
        }
    };
}
