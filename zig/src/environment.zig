const std = @import("std");
const Object = @import("object.zig").Object;

const Self = @This();

allocator: *std.mem.Allocator,
store: std.StringHashMap(Object),

pub fn newEnv(alloc: *std.mem.Allocator) !Self {
    return .{ .allocator = alloc, .store = std.StringHashMap(Object).init(alloc.*) };
}

pub fn get(self: *Self, name: []const u8) ?Object {
    return self.store.get(name);
}

pub fn put(self: *Self, name: []const u8, obj: Object) !Object {
    try self.store.putNoClobber(name, obj);
    return obj;
}

pub fn deinit(self: *Self) void {
    self.store.deinit();
}

pub fn printStore(self: *Self) void {
    var it = self.store.iterator();
    std.debug.print("store -\n", .{});
    while (it.next()) |value| {
        const key = value.key_ptr.*;
        const val = value.value_ptr.*;
        std.debug.print("key : {s}, value: {any}\n", .{ key, val });
    }
}
