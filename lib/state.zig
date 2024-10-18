const std = @import("std");
const utils = @import("utils");

const log = @import("log.zig");
const types = @import("types.zig");
const allocator = @import("lib.zig").allocator;

const Active = types.Active;
const Constraint = types.Constraint;
const ID = types.ID;
const List = types.List;
const String = types.String;

pub const CHRState = struct {
    next_id: ID = 0,
    store: std.AutoHashMap(ID, Constraint) = std.AutoHashMap(ID, Constraint).init(allocator),
    alive: utils.Set(ID) = utils.Set(ID).init(allocator),
    history: std.StringHashMap(List(utils.Set(ID))) = std.StringHashMap(List(utils.Set(ID))).init(allocator),
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
        if (self.store.get(id)) |existing| {
            log.debug("Removing {d} from store", .{existing});
            _ = self.store.remove(id);
        } else if (self.alive.has(id)) {
            log.debug("Removing active constraint from query", .{});
            _ = self.alive.remove(id);
        } else {
            log.debug("Could not remove ID {d}", .{id});
        }
    }

    pub fn add_to_query(self: *CHRState, id: ID, constraint: Constraint) !void {
        log.debug("Adding {d} to query", .{constraint});
        try self.query.push(Active{ .id = id, .constraint = constraint });
    }

    pub fn add_to_store(self: *CHRState, id: ID, constraint: Constraint) !void {
        log.debug("Adding {d} to store", .{constraint});
        try self.store.put(id, constraint);
    }

    pub fn add_to_history(self: *CHRState, rule: String, ids: utils.Set(ID)) !void {
        if (self.history.getPtr(rule)) |existing| {
            try existing.append(ids);
        } else {
            var set = List(utils.Set(ID)).init(allocator);
            try set.append(ids);
            try self.history.put(rule, set);
        }
    }

    pub fn is_in_history(self: CHRState, rule: String, ids: utils.Set(ID)) bool {
        if (self.history.get(rule)) |existing| {
            for (existing.items) |set| {
                if (set.equals(ids)) {
                    return true;
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
