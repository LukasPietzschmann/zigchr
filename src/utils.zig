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

        pub fn has(self: Set(T), elem: T) bool {
            return self.backing.contains(elem);
        }

        pub fn insert(self: *Set(T), elem: T) bool {
            self.backing.put(elem, void{}) catch {
                return false;
            };
            return true;
        }

        pub fn remove(self: *Set(T), elem: T) bool {
            return self.backing.remove(elem);
        }
    };
}

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

        pub fn push(self: *Queue(T), elem: T) bool {
            self.backing.append(elem) catch {
                return false;
            };
            return true;
        }

        pub fn pop(self: *Queue(T)) ?T {
            if (self.empty()) {
                return null;
            }
            return self.backing.pop();
        }
    };
}

pub fn concatSlices(comptime T: type, slice1: []const T, slice2: []const T) []T {
    const total_len = slice1.len + slice2.len;
    var allocator = std.heap.page_allocator;

    const result = allocator.alloc(T, total_len) catch unreachable;

    // TODO
    // std.mem.copy(T, result[0..slice1.len], slice1);
    // std.mem.copy(T, result[slice1.len..], slice2);

    return result;
}
