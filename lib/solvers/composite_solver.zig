const std = @import("std");

const log = @import("../log.zig");
const types = @import("../types.zig");

const CHRState = @import("../state.zig").CHRState;
const Solvable = @import("solvers.zig").Solvable;
const allocator = @import("../lib.zig").allocator;

const List = types.List;
const Active = types.Active;

pub const CompositeSolver = struct {
    const Self = @This();

    solvers: List(Solvable) = List(Solvable).init(allocator),

    pub fn solve(self: *Self, state: *CHRState, active: Active) !bool {
        for (self.solvers.items) |solver| {
            log.debug("Trying rule {s}", .{solver.name});
            if (try solver.solve(state, active)) {
                return true;
            }
        }
        return false;
    }

    pub fn init(self: *Self) Solvable {
        return Solvable.init(self, "Composite");
    }

    pub fn deinit(self: *Self) void {
        for (self.solvers.items) |solver| {
            solver.deinit();
        }
        self.solvers.deinit();
    }

    pub fn own(self: *Self, solver: Solvable) !void {
        try self.solvers.append(solver);
    }
};
