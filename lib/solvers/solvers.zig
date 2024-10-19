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
    const Self = @This();

    ptr: *anyopaque,
    solve_fn: *const fn (*anyopaque, state: *CHRState, active: Active) std.mem.Allocator.Error!bool,
    deinit_fn: *const fn (*anyopaque) void,
    name: String,

    pub fn init(ptr: anytype, name: String) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer or ptr_info.Pointer.size != .One)
            @compileError("Expected a pointer to a single value");

        const gen = struct {
            pub fn solveImpl(pointer: *anyopaque, state: *CHRState, active: Active) !bool {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return try @call(std.builtin.CallModifier.always_inline, ptr_info.Pointer.child.solve, .{ self, state, active });
            }

            pub fn deinitImpl(pointer: *anyopaque) void {
                if (!std.meta.hasMethod(ptr_info.Pointer.child, "deinit")) {
                    return;
                }
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(std.builtin.CallModifier.always_inline, ptr_info.Pointer.child.deinit, .{self});
            }
        };

        return .{
            .ptr = ptr,
            .solve_fn = gen.solveImpl,
            .deinit_fn = gen.deinitImpl,
            .name = name,
        };
    }

    pub inline fn deinit(self: Self) void {
        self.deinit_fn(self.ptr);
    }

    pub inline fn solve(self: Self, state: *CHRState, active: Active) !bool {
        return try self.solve_fn(self.ptr, state, active);
    }
};

pub fn runSolver(solver: Solvable, constraints: []Constraint) !CHRState {
    var state = CHRState{};

    for (constraints) |constraint| {
        const id = try state.new_id();
        try state.add_to_query(id, constraint);
    }

    while (!state.query.empty()) {
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
