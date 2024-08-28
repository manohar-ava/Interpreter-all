const std = @import("std");
const Ast = @import("abstract_syntax_tree.zig");
const object = @import("object.zig");
const Object = object.Object;

pub const Evaluator = struct {
    const Self = @This();
    allocator: *std.mem.Allocator,
    pub fn evaluate(self: *Self, node: Ast.Statement) Object {
        return switch (node) {
            .Program => self.evaluateStatements(node.Program),
            .expression_stmt => self.evaluateExpressionStatement(node.expression_stmt),
            else => @panic("invalid node type"),
        };
    }
    pub fn evaluateExpressionStatement(_: *Self, expStmt: Ast.ExpressionStatement) Object {
        return switch (expStmt.expression) {
            .integer => Object{ .Interger = .{ .value = expStmt.expression.integer.value } },
            else => @panic("paniceed"),
        };
    }
    pub fn evaluateStatements(self: *Self, program: Ast.Program) Object {
        var result: Object = undefined;
        for (program.statements.items) |stmt| {
            result = self.evaluate(stmt);
        }
        return result;
    }
};

pub fn newEval(alloc: *std.mem.Allocator) !*Evaluator {
    const eval = try alloc.create(Evaluator);
    eval.* = .{
        .allocator = alloc,
    };
    return eval;
}
