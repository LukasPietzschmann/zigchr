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

        pub fn add_to_query(self: *CHRState(C), id: ID, constraint: C) void {
            self.query.push(IdConstraintPair(C){ .id = id, .constraint = constraint });
        }

        pub fn add_to_store(self: *CHRState(C), id: ID, constraint: C) void {
            self.store.put(id, constraint);
        }

        pub fn new_id(self: *CHRState(C)) ID {
            const id = self.next_id;
            self.alive.insert(id);
            self.next_id += 1;
            return id;
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

fn CompositeSolver(comptime C: type, comptime S: type, solvers: []S) type {
    return struct {
        fn solve(state: *CHRState(C), active: []Active(C)) bool {
            for (solvers) |solver| {
                if (solver.solve(state, active)) {
                    return true;
                }
            }
            return false;
        }
    };
}

fn runSolver(comptime S: type, solver: S) type {
    return struct {
        fn run(constraints: []S.C, startState: ?*CHRState(S.C)) CHRState(S.C) {
            const state: CHRState(S.C) = undefined;
            if (startState == null) {
                state = CHRState(S.C){};
            } else {
                state = startState;
            }

            for (constraints) |constraint| {
                state.add_to_query(state.new_id(), constraint);
            }

            while (!state.query.empty()) {
                const current = state.query.pop().?;
                while (state.is_alive(current.id) and solver.solve(state, current)) {
                    continue;
                }
                if (state.is_alive(current.id)) {
                    state.add_to_store(current.id, current.constraint);
                }
            }
            return state;
        }
    };
}
