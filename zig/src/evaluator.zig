const std = @import("std");
const Ast = @import("abstract_syntax_tree.zig");
const object = @import("object.zig");
const environment = @import("environment.zig").Environment;
const tokens = @import("token.zig").tokens;
const Object = object.Object;

pub fn evaluate(alloc: std.mem.Allocator, node: anytype, env: *environment) !*Object {
    return try node.eval(alloc, env);
}
