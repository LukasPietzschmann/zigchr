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

fn Queue(comptime T: type) type {
    return struct {
        backing: []T = undefined,

        pub fn empty(self: *Queue(T)) bool {
            return self.backing.len == 0;
        }

        pub fn push(self: *Queue(T), elem: T) void {
            self.backing = std.array.append(self.backing, elem);
        }

        pub fn pop(self: *Queue(T)) ?T {
            if (self.empty()) {
                return null;
            }
            const elem = self.backing[0];
            self.backing = self.backing[1..];
            return elem;
        }
    };
}
