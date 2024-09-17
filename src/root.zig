const std = @import("std");
const utils = @import("utils.zig");

fn CHRState(comptime C: type) type {
    return struct {
        next_id: u32 = 0,
        store: std.AutoHashMap(u32, C) = .{},
        alive: utils.Set(u32) = .{},
        history: []std.meta.Tuple(.{ []u8, []u32 }) = .{},

        pub fn is_alive(self: *CHRState(C), id: u32) bool {
            self.alive.has(id);
        }

        pub fn kill(self: *CHRState(C), id: u32) void {
            self.store.remove(id);
            self.alive.remove(id);
        }

        pub fn constraints(self: *CHRState(C)) []C {
            var cs: []C = undefined;
            for (self.store.keys()) |id|
                cs = std.array.append(cs, self.store.get(id));
            return cs;
        }
    };
}

fn Active(comptime C: type) type {
    return struct {
        id: u32,
        constraint: C,
    };
}

fn RuleSolver(comptime C: type) type {
    return struct {
        fn solve(state: *CHRState(C), active: []Active(C)) bool {
            return false;
        }
    };
}

fn CompositeSolver(comptime C: type) type {
    return struct {
        fn solve(state: *CHRState(C), active: []Active(C)) bool {
            return false;
        }
    };
}
