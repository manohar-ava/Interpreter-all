const std = @import("std");
const object = @import("object.zig");

pub const TRUE = object.Boolean{ .value = true };
pub const FALSE = object.Boolean{ .value = false };
pub const NULL = object.Null{};

pub var TRUE_OBJECT = object.Object{ .Boolean = TRUE };
pub var FALSE_OBJECT = object.Object{ .Boolean = FALSE };
pub var NULL_OBJECT = object.Object{ .Null = NULL };
pub var FUNCTION_LEN_OBJECT = object.Object{
    .InBuiltFunction = .{
        .function = InBuiltFunction.len,
    },
};
pub var FUNCTION_PUSH_OBJECT = object.Object{
    .InBuiltFunction = .{
        .function = InBuiltFunction.push,
    },
};

pub fn getInBuiltFnRef(fnName: []const u8) ?*object.Object {
    if (std.mem.eql(u8, fnName, "len")) {
        return &FUNCTION_LEN_OBJECT;
    }
    if (std.mem.eql(u8, fnName, "push")) {
        return &FUNCTION_PUSH_OBJECT;
    }
    return null;
}

pub const InBuiltFunction = enum {
    len,
    push,
    // puts,
    pub fn call(self: InBuiltFunction, allocator: std.mem.Allocator, args: std.ArrayList(*object.Object)) !*object.Object {
        return switch (self) {
            .len => try len(allocator, args),
            .push => try push(allocator, args),
            // .puts => try puts(allocator, args),
        };
    }
};

fn push(alloc: std.mem.Allocator, args: std.ArrayList(*object.Object)) !*object.Object {
    if (try checkArgumentsLen(alloc, 2, args)) |err| {
        return err;
    }
    switch (args.items[0].*) {
        .ArrayLiteral => |arr| {
            var newItems = std.ArrayList(*object.Object).init(alloc);
            var i: usize = 0;
            while (i < arr.elements.items.len) : (i += 1) {
                try newItems.append(arr.elements.items[i]);
            }
            try newItems.append(args.items[1]);
            return object.newArray(alloc, newItems);
        },
        else => return object.newError(
            alloc,
            "func::Push does not support type: {s}",
            .{args.items[0].getType()},
        ),
    }
}

fn len(alloc: std.mem.Allocator, args: std.ArrayList(*object.Object)) !*object.Object {
    if (try checkArgumentsLen(alloc, 1, args)) |err| {
        return err;
    }
    switch (args.items[0].*) {
        .StringLiteral => |strOb| {
            return object.newInteger(alloc, @intCast(strOb.value.len));
        },
        .ArrayLiteral => |arr| return object.newInteger(alloc, @intCast(arr.elements.items.len)),
        else => return object.newError(
            alloc,
            "func::len does not support type: {s}",
            .{args.items[0].getType()},
        ),
    }
}

fn checkArgumentsLen(alloc: std.mem.Allocator, expect: usize, args: std.ArrayList(*object.Object)) !?*object.Object {
    if (args.items.len != expect) {
        return try object.newError(
            alloc,
            "wrong Number Of Arguments. Expected={}, Received={}",
            .{ expect, args.items.len },
        );
    } else {
        return null;
    }
}
