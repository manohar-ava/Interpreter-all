const std = @import("std");
const object = @import("object.zig");

pub const Environment = struct {
    outer: ?*Environment,
    env: std.StringHashMap(*object.Object),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn new(allocator: std.mem.Allocator) Self {
        return .{
            .outer = null,
            .env = std.StringHashMap(*object.Object).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn newEnclose(allocator: std.mem.Allocator, outer: *Environment) Self {
        return .{
            .outer = outer,
            .new = std.StringHashMap(*object.Object).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn get(self: Self, key: []const u8) ?*object.Object {
        const name = self.env.get(key);
        if (name != null) {
            return name;
        }

        if (self.outer) |outer| {
            return outer.get(key);
        } else {
            return null;
        }
    }

    pub fn insert(self: *Self, key: []const u8, value: *object.Object) !void {
        try self.env.put(key, value);
    }
};
