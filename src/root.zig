const std = @import("std");
const utils = @import("utils.zig");
const List = std.ArrayList;

pub const ID = u32;
pub const SHead = *const fn (u32) bool;
pub const Head = []SHead;
pub const Guard = *const fn ([]u32) bool;
pub const Body = *const fn ([]u32) []u32;
pub const String = []const u8;

pub const Active = struct {
    id: ID,
    constraint: u32,
};

pub const CHRState = struct {
    next_id: ID = 0,
    store: std.AutoHashMap(ID, u32) = std.AutoHashMap(ID, u32).init(std.heap.page_allocator),
    alive: utils.Set(ID) = utils.Set(ID).init(std.heap.page_allocator),
    history: std.StringHashMap(List(ID)) = std.StringHashMap(List(ID)).init(std.heap.page_allocator),
    query: utils.Queue(Active) = utils.Queue(Active).init(std.heap.page_allocator),

    pub fn is_alive(self: CHRState, id: ID) bool {
        return self.alive.has(id);
    }

    pub fn kill(self: *CHRState, id: ID) void {
        _ = self.store.remove(id);
        _ = self.alive.remove(id);
    }

    pub fn constraints(self: CHRState) []u32 {
        var cs: []u32 = undefined;
        for (self.store.keys()) |id|
            cs = std.array.append(cs, self.store.get(id));
        return cs;
    }

    pub fn add_to_query(self: *CHRState, id: ID, constraint: u32) void {
        _ = self.query.push(Active{ .id = id, .constraint = constraint });
    }

    pub fn add_to_store(self: *CHRState, id: ID, constraint: u32) void {
        self.store.put(id, constraint) catch unreachable;
    }

    pub fn add_to_history(self: *CHRState, rule: String, ids: []ID) void {
        if (self.history.get(rule)) |existing| {
            // for (ids) |id| {
            //     existing.append(id) catch unreachable;
            // }
            self.history.put(rule, existing) catch unreachable;
        } else {
            var id = List(ID).init(std.heap.page_allocator);
            for (ids) |d| {
                id.append(d) catch unreachable;
            }
            self.history.put(rule, id) catch unreachable;
        }
    }

    pub fn is_in_history(self: CHRState, rule: String, ids: []ID) bool {
        if (self.history.get(rule)) |existing| {
            if (existing.items.len != ids.len) {
                return false;
            }
            for (ids, 0..) |id, i| {
                if (existing.items[i] != id) {
                    return false;
                }
            }
        }
        return false;
    }

    pub fn new_id(self: *CHRState) ID {
        const id = self.next_id;
        _ = self.alive.insert(id);
        self.next_id += 1;
        return id;
    }
};

fn findMatchings(head: Head, active: Active, state: *CHRState) List([]Active) {
    const s = struct {
        const Self = @This();

        head: Head,
        active: Active,
        state: *CHRState,
        acc: List(Active) = List(Active).init(std.heap.page_allocator),

        var matchings: List([]Active) = List([]Active).init(std.heap.page_allocator);

        pub fn matching(self: *Self) List([]Active) {
            for (self.head, 0..) |head_constraint, i| {
                if (head_constraint(self.active.constraint)) {
                    var used = utils.Set(ID).init(std.heap.page_allocator);
                    _ = used.insert(self.active.id);
                    self.search(i, 0, &used);
                }
            }
            return matchings;
        }

        // Search the constraint store for a fitting match for the i-th head constraint
        fn search(self: *Self, headIdx: usize, i: usize, used: *utils.Set(ID)) void {
            if (i >= self.head.len) { // All head constraints have been matched
                matchings.append(self.acc.items) catch unreachable;
                return;
            }

            if (i == headIdx) { // The active constraint matched the constraint at head_idx
                self.acc.append(self.active) catch unreachable;
                self.search(headIdx, i + 1, used);
            } else {
                var it = self.state.store.keyIterator();
                while (it.next()) |id| { // Search the store for a fitting constraint
                    const storeConstraint = self.state.store.get(id.*) orelse continue;
                    if (self.head[i](storeConstraint)) {
                        _ = used.insert(id.*);
                        self.acc.append(Active{ .id = id.*, .constraint = storeConstraint }) catch unreachable;
                        self.search(headIdx, i + 1, used);
                    }
                }
            }
        }
    };

    var my_s = s{ .head = head, .active = active, .state = state };
    return my_s.matching();
}

inline fn selectMatch(matches: [][]Active) []Active {
    return matches[0];
}

const Solvable = struct {
    const Self = @This();

    ptr: *anyopaque,
    solve_fn: *const fn (*anyopaque, state: *CHRState, active: Active) bool,

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer or ptr_info.Pointer.size != .One) @compileError("Expected a pointer to a single value");

        // const alignment = ptr_info.Pointer.alignment;

        const gen = struct {
            pub fn solveImpl(pointer: *anyopaque, state: *CHRState, active: Active) bool {
                const self: Ptr = @ptrCast(@alignCast(pointer));
                return @call(std.builtin.CallModifier.always_inline, ptr_info.Pointer.child.solve, .{ self, state, active });
            }
        };

        return .{
            .ptr = ptr,
            .solve_fn = gen.solveImpl,
        };
    }

    pub inline fn solve(self: Self, state: *CHRState, active: Active) bool {
        return self.solve_fn(self.ptr, state, active);
    }
};

pub const RuleSolver = struct {
    const Self = @This();

    name: String,
    kh: Head,
    rh: Head,
    g: Guard,
    b: Body,

    pub fn solve(self: *Self, state: *CHRState, active: Active) bool {
        var matches: List([]Active) = List([]Active).init(std.heap.page_allocator);
        const x = utils.concatSlices(SHead, self.kh, self.rh);
        for (findMatchings(x, active, state).items) |match| {
            var matchIds = List(ID).init(std.heap.page_allocator);
            var matchValues = List(u32).init(std.heap.page_allocator);
            for (match) |m| {
                matchIds.append(m.id) catch unreachable;
                matchValues.append(m.constraint) catch unreachable;
            }

            if (!self.g(matchValues.items) or (self.rh.len == 0 and state.is_in_history(self.name, matchIds.items))) {
                continue;
            }

            matches.append(match) catch unreachable;
        }

        if (matches.items.len == 0) {
            return false;
        }

        const match = selectMatch(matches.items);

        var matchIds = List(ID).init(std.heap.page_allocator);
        var matchValues = List(u32).init(std.heap.page_allocator);
        for (match) |m| {
            matchIds.append(m.id) catch unreachable;
            matchValues.append(m.constraint) catch unreachable;
        }

        for (matchIds.items[self.kh.len..]) |rhMatchId| {
            state.kill(rhMatchId);
        }

        for (self.b(matchValues.items)) |resultingConstraint| {
            state.add_to_query(state.new_id(), resultingConstraint);
        }

        if (self.rh.len == 0) {
            state.add_to_history(self.name, matchIds.items);
        }

        return true;
    }

    pub fn init(self: *Self) Solvable {
        return Solvable.init(self);
    }
};

pub const CompositeSolver = struct {
    const Self = @This();

    solvers: []Solvable,

    pub fn solve(self: *Self, state: *CHRState, active: Active) bool {
        for (self.solvers) |solver| {
            if (solver.solve(state, active)) {
                return true;
            }
        }
        return false;
    }

    pub fn init(self: *Self, solvers: []Solvable) Solvable {
        solvers = solvers;
        return Solvable.init(self);
    }
};

pub fn runSolver(solver: Solvable, constraints: []u32, startState: ?CHRState) CHRState {
    var state = startState orelse CHRState{};

    for (constraints) |constraint| {
        state.add_to_query(state.new_id(), constraint);
    }

    while (!state.query.empty()) {
        const current = state.query.pop().?;
        while (state.is_alive(current.id) and solver.solve(&state, current)) {
            continue;
        }
        if (state.is_alive(current.id)) {
            state.add_to_store(current.id, current.constraint);
        }
    }
    return state;
}
