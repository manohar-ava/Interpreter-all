const std = @import("std");
const Ast = @import("abstract_syntax_tree.zig");
const object = @import("object.zig");
const tokens = @import("token.zig").tokens;
const Object = object.Object;

pub fn evaluate(alloc: *std.mem.Allocator, node: anytype) !?Object {
    const x = try node.eval(alloc);
    std.debug.print("eval: {} \n", .{x});
    return switch (x) {
        .Null => null,
        else => x,
    };
}
