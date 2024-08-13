const std = @import("std");
const token = @import("./token.zig");

pub const Statement = union(enum) {
    let: LetStatement,
    return_stmt: ReturnStatement,
    expression_stmt: ExpressionStatement,
    pub fn string(self: *const Statement, str: *std.ArrayList(u8)) !void {
        return switch (self.*) {
            .let => |item| {
                try item.string(str);
            },
            else => @panic("you are extremely stupid"),
        };
    }
};

pub const Expression = union(enum) {
    identifier: Identifier,
    integer: IntegerLiteral,
};

pub const LetStatement = struct {
    identifier: Identifier = undefined,
    value: ExpressionStatement = undefined,
    pub fn string(self: *const LetStatement, str: *std.ArrayList(u8)) !void {
        try str.appendSlice("let ");
        try self.identifier.string(str);
        try str.appendSlice(" = ");
        // try self.value.string(str);
        try str.appendSlice(";");
    }
};

pub const ReturnStatement = struct { value: ExpressionStatement = undefined };
pub const ExpressionStatement = struct {
    expression: Expression = undefined,
    token: token.tokens = undefined,
    // pub fn string(self: *const ExpressionStatement, str: *std.ArrayList(u8)) !void {
    // try str.appendSlice(self.expression);
    // }
};

pub const Identifier = struct {
    name: []const u8,
    pub fn string(self: *const Identifier, str: *std.ArrayList(u8)) !void {
        try str.appendSlice(self.name);
    }
};

pub const IntegerLiteral = struct {
    value: i64,
    pub fn string(self: *const IntegerLiteral, str: *std.ArrayList(u8)) !void {
        try str.appendSlice(self.value);
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),
    pub fn getToken(self: *Program) token.tokens {
        return self.statements[0].getToken();
    }
};
