const std = @import("std");
const config = @import("config");
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
    store: std.AutoHashMapUnmanaged(ID, Constraint) = .{},
    alive: utils.Set(ID) = utils.Set(ID){},
    history: std.StringHashMapUnmanaged(List(utils.Set(ID))) = .{},
    query: List(Active) = .empty,

    pub fn deinit(self: *CHRState) void {
        self.store.deinit(allocator);
        self.alive.deinit(allocator);
        self.history.deinit(allocator);
        self.query.deinit(allocator);
    }

    fn print_store(self: CHRState) void {
        log.debug("========== Store ==========", .{});
        var it = self.store.valueIterator();
        while (it.next()) |constraint| {
            log.debug("{f}", .{constraint.*});
        }
        log.debug("===========================", .{});
    }

    pub fn is_alive(self: CHRState, id: ID) bool {
        return self.alive.has(id);
    }

    pub fn kill(self: *CHRState, id: ID) void {
        if (self.store.get(id)) |existing| {
            log.debug("Removing {f} from store", .{existing});
            _ = self.store.remove(id);
            if (config.show_store)
                self.print_store();
        } else if (self.alive.has(id)) {
            log.debug("Removing active constraint from query", .{});
            _ = self.alive.remove(id);
        } else {
            log.debug("Could not remove ID {d}", .{id});
        }
    }

    pub fn add_to_query(self: *CHRState, id: ID, constraint: Constraint) !void {
        log.debug("Adding {f} to query", .{constraint});
        try self.query.append(allocator, .{ .id = id, .constraint = constraint });
    }

    pub fn add_to_store(self: *CHRState, id: ID, constraint: Constraint) !void {
        log.debug("Adding {f} to store", .{constraint});
        try self.store.put(allocator, id, constraint);
        if (config.show_store)
            self.print_store();
    }

    pub fn add_to_history(self: *CHRState, rule: String, ids: utils.Set(ID)) !void {
        if (self.history.getPtr(rule)) |existing| {
            try existing.append(allocator, ids);
        } else {
            var set = List(utils.Set(ID)){};
            try set.append(allocator, ids);
            try self.history.put(allocator, rule, set);
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
        try self.alive.insert(allocator, id);
        self.next_id += 1;
        return id;
    }
};
