const std = @import("std");

pub const predefined = @import("predefined/predefined.zig");
pub const solvers = @import("solvers/solvers.zig");
pub const types = @import("types.zig");
pub const CHRState = @import("state.zig").CHRState;

const Constraint = types.Constraint;
const SHead = types.SHead;
const Head = types.Head;
const List = types.List;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub fn as_head(f: SHead) !List(SHead) {
    var list = List(SHead).init(allocator);
    try list.append(f);
    return list;
}

pub fn concat(h1: Head, h2: Head) !Head {
    var res = Head.init(allocator);
    try res.appendSlice(h1.items);
    try res.appendSlice(h2.items);
    return res;
}

pub fn emptyHead() !Head {
    return Head.init(allocator);
}

pub fn deinit() void {
    _ = gpa.deinit();
}

pub fn argv_to_query() ![]Constraint {
    var cs = List(Constraint).init(allocator);
    var it = std.process.args();
    _ = it.skip();
    while (it.next()) |arg| {
        const c = try std.fmt.parseInt(Constraint, arg, 10);
        try cs.append(c);
    }
    return cs.toOwnedSlice();
}
