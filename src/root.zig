const std = @import("std");

const utils = @import("utils.zig");
const List = std.ArrayList;

pub const ID = u32;
pub const SHead = *const fn (u32) bool;
pub const Head = List(SHead);
pub const Guard = *const fn ([]u32) bool;
pub const Body = *const fn ([]u32) []u32;
pub const String = []const u8;

// TODO: Make non thread safe
var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = false, .verbose_log = false }){};
const allocator = gpa.allocator();

pub fn toHead(f: *const fn (u32) bool) List(SHead) {
    var list = List(SHead).init(allocator);
    list.append(f) catch unreachable;
    return list;
}

pub fn merge(comptime T: type, l1: List(T), l2: List(T)) List(T) {
    var list = List(T).init(allocator);
    list.appendSlice(l1.items) catch unreachable;
    list.appendSlice(l2.items) catch unreachable;
    return list;
}

pub const Active = struct {
    id: ID,
    constraint: u32,

    pub fn format(self: Active, comptime fmt: String, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}: {d}", .{ self.id, self.constraint });
    }
};

pub const CHRState = struct {
    next_id: ID = 0,
    store: std.AutoHashMap(ID, u32) = std.AutoHashMap(ID, u32).init(allocator),
    alive: utils.Set(ID) = utils.Set(ID).init(allocator),
    history: std.StringHashMap(List(ID)) = std.StringHashMap(List(ID)).init(allocator),
    query: utils.Queue(Active) = utils.Queue(Active).init(allocator),

    pub fn is_alive(self: CHRState, id: ID) bool {
        return self.alive.has(id);
    }

    pub fn kill(self: *CHRState, id: ID) void {
        _ = self.store.remove(id);
        _ = self.alive.remove(id);
        std.debug.print("Store containing {d} constraints\n", .{self.store.count()});
    }

    pub fn add_to_query(self: *CHRState, id: ID, constraint: u32) void {
        _ = self.query.push(Active{ .id = id, .constraint = constraint });
    }

    pub fn add_to_store(self: *CHRState, id: ID, constraint: u32) void {
        std.debug.print("Adding {d} to store\n", .{constraint});
        self.store.put(id, constraint) catch unreachable;
        std.debug.print("Store containing {d} constraints\n", .{self.store.count()});
    }

    pub fn add_to_history(self: *CHRState, rule: String, ids: []ID) void {
        if (self.history.get(rule)) |existing| {
            // for (ids) |id| {
            //     existing.append(id) catch unreachable;
            // }
            self.history.put(rule, existing) catch unreachable;
        } else {
            var id = List(ID).init(allocator);
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

fn findMatchings(head: Head, active: Active, state: *CHRState) [][]Active {
    const s = struct {
        const Self = @This();

        head: Head,
        active: Active,
        state: *CHRState,

        headIdx: usize = undefined,
        acc: List(Active) = List(Active).init(allocator),
        used: utils.Set(ID) = utils.Set(ID).init(allocator),

        var matchings: List([]Active) = List([]Active).init(allocator);

        pub fn matching(self: *Self) [][]Active {
            for (self.head.items, 0..) |head_constraint, i| {
                if (head_constraint(self.active.constraint)) {
                    // self.acc.clearAndFree(); // unnecessary but it does not hurt either
                    self.used.clearRetainingCapacity();
                    self.headIdx = i;

                    _ = self.used.insert(self.active.id);
                    self.search(0);
                }
            }
            return matchings.toOwnedSlice() catch unreachable;
        }

        // Search the constraint store for a fitting match for the i-th head constraint
        fn search(self: *Self, i: usize) void {
            if (i >= self.head.items.len) { // All head constraints have been matched
                // std.debug.print("Adding {p}\n", .{self.acc.items});
                matchings.append(self.acc.toOwnedSlice() catch unreachable) catch unreachable;
                return;
            }

            if (i == self.headIdx) { // The active constraint matched the constraint at head_idx
                self.acc.append(self.active) catch unreachable;
                _ = self.used.insert(self.active.id);
                self.search(i + 1);
            } else {
                var it = self.state.store.keyIterator();
                while (it.next()) |id| { // Search the store for a fitting constraint
                    const storeConstraint = self.state.store.get(id.*) orelse unreachable;
                    if (self.used.has(id.*)) {
                        std.debug.print("{d} already used\n", .{storeConstraint});
                        continue;
                    }
                    if (self.head.items[i](storeConstraint)) {
                        std.debug.print("Adding {d} from store\n", .{storeConstraint});
                        const new = Active{ .id = id.*, .constraint = storeConstraint };
                        self.acc.append(new) catch unreachable;
                        _ = self.used.insert(new.id);
                        self.search(i + 1);
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
        std.debug.print("Start solving for {d}\n", .{active.constraint});
        var matches: List([]Active) = List([]Active).init(allocator);
        const complete_head = merge(SHead, self.kh, self.rh);
        const matchings = findMatchings(complete_head, active, state);
        std.debug.print("Found {d} matchings\n", .{matchings.len});
        for (matchings) |match| {
            // std.debug.print("{any}\n", .{match});
            var matchIds = List(ID).init(allocator);
            var matchValues = List(u32).init(allocator);
            for (match) |m| {
                matchIds.append(m.id) catch unreachable;
                matchValues.append(m.constraint) catch unreachable;
            }

            if (!self.g(matchValues.items) or (self.rh.items.len == 0 and state.is_in_history(self.name, matchIds.items))) {
                continue;
            }

            matches.append(match) catch unreachable;
        }
        complete_head.deinit();

        if (matches.items.len == 0) {
            return false;
        }

        const match = selectMatch(matches.items);
        std.debug.print("Match: {any}\n", .{match});

        var matchIds = List(ID).init(allocator);
        var matchValues = List(u32).init(allocator);
        for (match) |m| {
            matchIds.append(m.id) catch unreachable;
            matchValues.append(m.constraint) catch unreachable;
        }

        for (match[self.kh.items.len..]) |rhMatch| {
            std.debug.print("Killing {d}\n", .{rhMatch.constraint});
            state.kill(rhMatch.id);
        }

        for (self.b(matchValues.items)) |resultingConstraint| {
            state.add_to_query(state.new_id(), resultingConstraint);
        }

        if (self.rh.items.len == 0) {
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
    std.debug.print("Running solver\n", .{});
    var state = startState orelse CHRState{};

    for (constraints) |constraint| {
        std.debug.print("Adding {d} to query\n", .{constraint});
        state.add_to_query(state.new_id(), constraint);
    }

    while (!state.query.empty()) {
        const current = state.query.pop().?;
        while (state.is_alive(current.id) and solver.solve(&state, current)) {
            continue;
        }
        if (state.is_alive(current.id)) {
            std.debug.print("Solver could not go ahead for constraint {d}\n", .{current.constraint});
            state.add_to_store(current.id, current.constraint);
        }
    }
    return state;
}
