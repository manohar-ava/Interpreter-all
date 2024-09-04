const std = @import("std");
const Object = @import("object.zig").Object;

const Self = @This();

allocator: *std.mem.Allocator,
outerEnv: ?*Self,
store: std.StringHashMap(Object),

pub fn newEnv(alloc: *std.mem.Allocator) !*Self {
    var env = try alloc.create(Self);
    env.allocator = alloc;
    env.outerEnv = null;
    env.store = std.StringHashMap(Object).init(alloc.*);
    return env;
}

pub fn newEnclosedEnv(alloc: *std.mem.Allocator, outerEnv: *Self) !*Self {
    var env = try newEnv(alloc);
    env.outerEnv = outerEnv;
    return env;
}

pub fn get(self: *Self, Name: []const u8) ?Object {
    const name = self.allocator.dupe(u8, Name) catch {
        @panic("dumbass");
    };
    if (self.store.contains(name)) {
        return self.store.get(name);
    } else if (self.outerEnv) |outer| {
        std.debug.print("{s}  {} is key in outer\n", .{ name, outer.store.contains(name) });
        if (outer.store.contains(name)) {
            return outer.get(name);
        }
    }
    std.debug.print("{s} : doesn't exist in store or outstore\n", .{name});
    return self.store.get(name);
}

pub fn put(self: *Self, Name: []const u8, obj: Object) !Object {
    const name = try self.allocator.dupe(u8, Name);
    try self.store.putNoClobber(name, obj);
    std.debug.print("============+\n", .{});
    self.printStore();
    std.debug.print("============-\n", .{});
    return obj;
}

pub fn deinit(self: *Self) void {
    self.store.deinit();
}

pub fn printStore(self: *Self) void {
    var it = self.store.iterator();
    while (it.next()) |value| {
        const key = value.key_ptr.*;
        const val = value.value_ptr.*;
        std.debug.print("key : {s}, value: {any}\n", .{ key, val });
    }
}
