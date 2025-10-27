const std = @import("std");

const types = @import("../types.zig");
const log = @import("../log.zig");
const CHRState = @import("../state.zig").CHRState;

const allocator = @import("../lib.zig").allocator;

const Active = types.Active;
const Constraint = types.Constraint;
const String = types.String;

const rs = @import("rule_solver.zig");

pub const RuleSolver = rs.RuleSolver;
pub const CompositeSolver = @import("composite_solver.zig").CompositeSolver;

pub const propagation = rs.propagation;
pub const simplification = rs.simplification;
pub const simpagation = rs.simpagation;

pub const Solvable = struct {
    ptr: *anyopaque,
    solve_fn: *const fn (*anyopaque, state: *CHRState, active: Active) std.mem.Allocator.Error!bool,
    deinit_fn: *const fn (*anyopaque) void,
    name: String,

    pub fn init(ptr: anytype, name: String) Solvable {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer or ptr_info.pointer.size != .one)
            @compileError("Expected a pointer to a single value");

        const gen = struct {
            pub fn solveImpl(pointer: *anyopaque, state: *CHRState, active: Active) !bool {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return try self.solve(state, active);
            }

            pub fn deinitImpl(pointer: *anyopaque) void {
                if (!std.meta.hasMethod(ptr_info.pointer.child, "deinit")) {
                    return;
                }
                const self: Ptr = @ptrCast(@alignCast(pointer));
                self.deinit();
            }
        };

        return .{
            .ptr = ptr,
            .solve_fn = gen.solveImpl,
            .deinit_fn = gen.deinitImpl,
            .name = name,
        };
    }

    pub fn deinit(self: Solvable) void {
        self.deinit_fn(self.ptr);
    }

    pub fn solve(self: Solvable, state: *CHRState, active: Active) !bool {
        return try self.solve_fn(self.ptr, state, active);
    }
};

pub fn runSolver(solver: Solvable, constraints: []Constraint) !CHRState {
    var state = CHRState{};

    for (constraints) |constraint| {
        const id = try state.new_id();
        try state.add_to_query(id, constraint);
    }

    while (state.query.items.len != 0) {
        const current = state.query.pop().?;
        while (state.is_alive(current.id) and try solver.solve(&state, current)) {
            continue;
        }
        if (state.is_alive(current.id)) {
            try state.add_to_store(current.id, current.constraint);
        }
    }
    log.debug("Reached end of query", .{});
    return state;
}
