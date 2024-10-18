const std = @import("std");
const utils = @import("utils");

const lib = @import("../lib.zig");
const types = @import("../types.zig");
const CHRState = @import("../state.zig").CHRState;
const Solvable = @import("solvers.zig").Solvable;

const Active = types.Active;
const Constraint = types.Constraint;
const Body = types.Body;
const Guard = types.Guard;
const Head = types.Head;
const ID = types.ID;
const List = types.List;
const SHead = types.SHead;
const String = types.String;

const allocator = lib.allocator;

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
        const complete_head = try lib.concat(self.kh, self.rh);
        const matchings = try findMatchings(complete_head, active, state);
        for (matchings) |match| {
            var matchIds = utils.Set(ID).init(allocator);
            var matchValues = List(Constraint).init(allocator);
            defer {
                matchIds.deinit();
                matchValues.deinit();
            }

            for (match) |m| {
                try matchIds.insert(m.id);
                try matchValues.append(m.constraint);
            }

            if (!self.g(matchValues.items) or (self.rh.items.len == 0 and state.is_in_history(self.name, matchIds))) {
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

        var matchIds = utils.Set(ID).init(allocator);
        var matchValues = List(Constraint).init(allocator);
        defer {
            matchIds.deinit();
            matchValues.deinit();
        }

        for (match) |m| {
            try matchIds.insert(m.id);
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
            try state.add_to_history(self.name, matchIds);
        }

        return true;
    }

    pub fn init(self: *Self) Solvable {
        return Solvable.init(self, self.name);
    }

    pub fn deinit(self: *Self) void {
        self.kh.deinit();
        self.rh.deinit();
    }
};

pub inline fn propagation(name: String, head: Head, guard: Guard, body: Body) !RuleSolver {
    return RuleSolver{
        .name = name,
        .kh = head,
        .rh = try lib.emptyHead(),
        .g = guard,
        .b = body,
    };
}

pub inline fn simplification(name: String, head: Head, guard: Guard, body: Body) !RuleSolver {
    return RuleSolver{
        .name = name,
        .kh = try lib.emptyHead(),
        .rh = head,
        .g = guard,
        .b = body,
    };
}

pub inline fn simpagation(name: String, kh: Head, rh: Head, guard: Guard, body: Body) RuleSolver {
    return RuleSolver{
        .name = name,
        .kh = kh,
        .rh = rh,
        .g = guard,
        .b = body,
    };
}

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
