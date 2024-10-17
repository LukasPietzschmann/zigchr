const std = @import("std");

const utils = @import("utils.zig");
const List = std.ArrayList;

pub const ID = u32;
pub const SHead = *const fn (u32) bool;
pub const Head = List(SHead);
pub const Guard = *const fn ([]u32) bool;
pub const Body = *const fn ([]u32) []u32;
pub const String = []const u8;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn deinit() void {
    _ = gpa.deinit();
}

pub fn toHead(f: *const fn (u32) bool) !List(SHead) {
    var list = List(SHead).init(allocator);
    try list.append(f);
    return list;
}

pub fn merge(comptime T: type, l1: List(T), l2: List(T)) !List(T) {
    var list = List(T).init(allocator);
    try list.appendSlice(l1.items);
    try list.appendSlice(l2.items);
    return list;
}

pub const Active = struct {
    id: ID,
    constraint: u32,

    pub fn format(self: Active, comptime fmt: String, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{d}", .{self.constraint});
    }
};

pub const CHRState = struct {
    next_id: ID = 0,
    store: std.AutoHashMap(ID, u32) = std.AutoHashMap(ID, u32).init(allocator),
    alive: utils.Set(ID) = utils.Set(ID).init(allocator),
    history: std.StringHashMap(List(ID)) = std.StringHashMap(List(ID)).init(allocator),
    query: utils.Queue(Active) = utils.Queue(Active).init(allocator),

    pub fn deinit(self: *CHRState) void {
        self.store.deinit();
        self.alive.deinit();
        self.history.deinit();
        self.query.deinit();
    }

    pub fn is_alive(self: CHRState, id: ID) bool {
        return self.alive.has(id);
    }

    pub fn kill(self: *CHRState, id: ID) void {
        const existing = self.store.get(id) orelse return;
        std.log.debug("Removing {d} from store", .{existing});
        _ = self.store.remove(id);
        _ = self.alive.remove(id);
    }

    pub fn add_to_query(self: *CHRState, id: ID, constraint: u32) !void {
        try self.query.push(Active{ .id = id, .constraint = constraint });
    }

    pub fn add_to_store(self: *CHRState, id: ID, constraint: u32) !void {
        std.log.debug("Adding {d} to store", .{constraint});
        try self.store.put(id, constraint);
    }

    pub fn add_to_history(self: *CHRState, rule: String, ids: []ID) !void {
        if (self.history.get(rule)) |existing| {
            // for (ids) |id| {
            //     existing.append(id) catch unreachable;
            // }
            try self.history.put(rule, existing);
        } else {
            var id = List(ID).init(allocator);
            for (ids) |d| {
                try id.append(d);
            }
            try self.history.put(rule, id);
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

    pub fn new_id(self: *CHRState) !ID {
        const id = self.next_id;
        try self.alive.insert(id);
        self.next_id += 1;
        return id;
    }
};

fn findMatchings(head: Head, active: Active, state: *CHRState) ![][]Active {
    const s = struct {
        const Self = @This();

        head: Head,
        active: Active,
        state: *CHRState,

        headIdx: usize = undefined,
        acc: List(Active),
        used: utils.Set(ID),

        matchings: List([]Active),

        pub fn init(h: Head, a: Active, s: *CHRState) Self {
            return .{ .head = h, .active = a, .state = s, .acc = List(Active).init(allocator), .used = utils.Set(ID).init(allocator), .matchings = List([]Active).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.acc.deinit();
            self.used.deinit();
            self.matchings.deinit();
        }

        pub fn matching(self: *Self) ![][]Active {
            for (self.head.items, 0..) |head_constraint, i| {
                if (head_constraint(self.active.constraint)) {
                    self.acc.clearAndFree();
                    self.used.clearAndFree();
                    self.headIdx = i;

                    try self.used.insert(self.active.id);
                    try self.search(0);
                }
            }
            return try self.matchings.toOwnedSlice();
        }

        // Search the constraint store for a fitting match for the i-th head constraint
        fn search(self: *Self, i: usize) !void {
            if (i >= self.head.items.len) { // All head constraints have been matched
                try self.matchings.append(try self.acc.toOwnedSlice());
                return;
            }

            if (i == self.headIdx) { // The active constraint matched the constraint at head_idx
                try self.acc.append(self.active);
                try self.used.insert(self.active.id);
                try self.search(i + 1);
            } else {
                var it = self.state.store.keyIterator();
                while (it.next()) |id| { // Search the store for a fitting constraint
                    if (self.used.has(id.*)) continue;

                    const storeConstraint = self.state.store.get(id.*) orelse unreachable;
                    if (self.head.items[i](storeConstraint)) {
                        const new = Active{ .id = id.*, .constraint = storeConstraint };
                        try self.acc.append(new);
                        try self.used.insert(new.id);
                        try self.search(i + 1);
                    }
                }
            }
        }
    };

    var my_s = s.init(head, active, state);
    defer my_s.deinit();

    return try my_s.matching();
}

inline fn selectMatch(matches: [][]Active) []Active {
    return matches[0];
}

const Solvable = struct {
    const Self = @This();

    ptr: *anyopaque,
    solve_fn: *const fn (*anyopaque, state: *CHRState, active: Active) std.mem.Allocator.Error!bool,
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
        };

        return .{
            .ptr = ptr,
            .solve_fn = gen.solveImpl,
            .name = name,
        };
    }

    pub inline fn solve(self: Self, state: *CHRState, active: Active) !bool {
        return try self.solve_fn(self.ptr, state, active);
    }
};

pub const RuleSolver = struct {
    const Self = @This();

    name: String,
    kh: Head,
    rh: Head,
    g: Guard,
    b: Body,

    pub fn solve(self: *Self, state: *CHRState, active: Active) !bool {
        std.log.debug("Process {d}", .{active.constraint});
        var matches: List([]Active) = List([]Active).init(allocator);
        defer matches.deinit();
        const complete_head = try merge(SHead, self.kh, self.rh);
        const matchings = try findMatchings(complete_head, active, state);
        for (matchings) |match| {
            var matchIds = List(ID).init(allocator);
            var matchValues = List(u32).init(allocator);
            defer {
                matchIds.deinit();
                matchValues.deinit();
            }

            for (match) |m| {
                try matchIds.append(m.id);
                try matchValues.append(m.constraint);
            }

            if (!self.g(matchValues.items) or (self.rh.items.len == 0 and state.is_in_history(self.name, matchIds.items))) {
                continue;
            }

            try matches.append(match);
        }
        allocator.free(matchings);
        complete_head.deinit();

        if (matches.items.len == 0) {
            std.log.debug("Could not apply rule {s}", .{self.name});
            return false;
        }

        const match = selectMatch(matches.items);

        std.log.debug("Fire rule {s} with {any}", .{ self.name, match });

        var matchIds = List(ID).init(allocator);
        var matchValues = List(u32).init(allocator);
        defer {
            matchIds.deinit();
            matchValues.deinit();
        }

        for (match) |m| {
            try matchIds.append(m.id);
            try matchValues.append(m.constraint);
        }

        for (match[self.kh.items.len..]) |rhMatch| {
            state.kill(rhMatch.id);
        }

        for (self.b(matchValues.items)) |resultingConstraint| {
            const id = try state.new_id();
            try state.add_to_query(id, resultingConstraint);
        }

        if (self.rh.items.len == 0) {
            try state.add_to_history(self.name, matchIds.items);
        }

        return true;
    }

    pub fn init(self: *Self) Solvable {
        return Solvable.init(self, self.name);
    }
};

pub const CompositeSolver = struct {
    const Self = @This();

    solvers: []Solvable,

    pub fn solve(self: *Self, state: *CHRState, active: Active) bool {
        for (self.solvers) |solver| {
            std.log.debug("Trying rule {s}", .{solver.name});
            if (solver.solve(state, active)) {
                return true;
            }
        }
        return false;
    }

    pub fn init(self: *Self, solvers: []Solvable) Solvable {
        solvers = solvers;
        return Solvable.init(self, "Composite");
    }
};

pub fn runSolver(solver: Solvable, constraints: []u32) !CHRState {
    var state = CHRState{};

    for (constraints) |constraint| {
        std.log.debug("Adding {d} to query", .{constraint});
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
    return state;
}
