const std = @import("std");
const utils = @import("utils");
const config = @import("config");

const log = @import("../log.zig");
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
    name: String,
    kh: Head,
    rh: Head,
    g: Guard,
    b: Body,

    pub fn solve(self: *RuleSolver, state: *CHRState, active: Active) !bool {
        log.debug("Process {f}", .{active.constraint});
        var complete_head = try lib.concat(self.kh, self.rh);
        const all_matchings = try findMatchings(complete_head, active, state);
        var fitting_matchings = List([]Active).empty;
        defer {
            fitting_matchings.deinit(allocator);
            complete_head.deinit(allocator);
            for (all_matchings) |match| {
                allocator.free(match);
            }
            allocator.free(all_matchings);
        }

        if (config.show_matchings) {
            log.debug("Matchings: {f}", .{Active.FmtSlices{ .slices = all_matchings }});
        }

        for (all_matchings) |match| {
            var matchIds = utils.Set(ID){};
            var matchValues = List(Constraint).empty;
            defer {
                matchIds.deinit(allocator);
                matchValues.deinit(allocator);
            }

            for (match) |m| {
                try matchIds.insert(allocator, m.id);
                try matchValues.append(allocator, m.constraint);
            }

            if (match.len != complete_head.items.len) {
                continue;
            }

            if (!self.g(matchValues.items) or (self.rh.items.len == 0 and state.is_in_history(self.name, matchIds))) {
                continue;
            }

            try fitting_matchings.append(allocator, match);
        }

        if (fitting_matchings.items.len == 0) {
            log.debug("Could not apply rule {s}", .{self.name});
            return false;
        }

        const match = selectMatch(fitting_matchings.items);

        log.debug("Fire rule {s} with {f}", .{ self.name, Active.FmtSlice{ .slice = match } });

        var matchIds = utils.Set(ID){};
        var matchValues = List(Constraint).empty;
        defer {
            matchIds.deinit(allocator);
            matchValues.deinit(allocator);
        }

        for (match) |m| {
            try matchIds.insert(allocator, m.id);
            try matchValues.append(allocator, m.constraint);
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

    pub fn init(self: *RuleSolver) Solvable {
        return .init(self, self.name);
    }

    pub fn deinit(self: *RuleSolver) void {
        self.kh.deinit(allocator);
        self.rh.deinit(allocator);
    }
};

pub fn propagation(name: String, head: Head, guard: Guard, body: Body) !RuleSolver {
    return simpagation(name, head, .empty, guard, body);
}

pub fn simplification(name: String, head: Head, guard: Guard, body: Body) !RuleSolver {
    return simpagation(name, .empty, head, guard, body);
}

pub fn simpagation(name: String, kh: Head, rh: Head, guard: Guard, body: Body) RuleSolver {
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
            return .{
                .head = h,
                .active = a,
                .state = s,
                .acc = .empty,
                .used = utils.Set(ID){},
                .matchings = .empty,
            };
        }

        pub fn deinit(self: *Self) void {
            self.acc.deinit(allocator);
            self.used.deinit(allocator);
            self.matchings.deinit(allocator);
        }

        pub fn matching(self: *Self) ![][]Active {
            for (self.head.items, 0..) |head_constraint, i| {
                if (head_constraint.op(self.active.constraint, head_constraint.n)) {
                    self.acc.clearRetainingCapacity();
                    self.used.clearRetainingCapacity();
                    self.headIdx = i;

                    try self.used.insert(allocator, self.active.id);
                    try self.search(0);
                }
            }
            return try self.matchings.toOwnedSlice(allocator);
        }

        // Search the constraint store for a fitting match for the i-th head constraint
        fn search(self: *Self, i: usize) !void {
            if (i >= self.head.items.len) { // All head constraints have been matched
                try self.matchings.append(allocator, try self.acc.toOwnedSlice(allocator));
                return;
            }

            if (i == self.headIdx) { // The active constraint matched the constraint at head_idx
                try self.acc.append(allocator, self.active);
                try self.used.insert(allocator, self.active.id);
                try self.search(i + 1);
            } else {
                var it = self.state.store.keyIterator();
                while (it.next()) |id| { // Search the store for a fitting constraint
                    if (self.used.has(id.*)) continue;

                    const storeConstraint = self.state.store.get(id.*).?;
                    if (self.head.items[i].op(storeConstraint, self.head.items[i].n)) {
                        const new = Active{ .id = id.*, .constraint = storeConstraint };
                        try self.acc.append(allocator, new);
                        try self.used.insert(allocator, new.id);
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

fn selectMatch(matches: [][]Active) []Active {
    return matches[0];
}
