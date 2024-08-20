const std = @import("std");
const token = @import("./token.zig");

pub const Statement = union(enum) {
    let: LetStatement,
    return_stmt: ReturnStatement,
    expression_stmt: ExpressionStatement,
    block_stmt: BlockStatement,
    pub fn format(self: Statement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        std.log.info("{}", .{@TypeOf(self)});
        switch (self) {
            inline else => |item| try writer.print("{}", .{item}),
        }
    }
};

pub const Expression = union(enum) {
    identifier: Identifier,
    integer: IntegerLiteral,
    prefix_exp: PrefixExpression,
    infix_exp: InfixExpression,
    boolean_exp: BooleanExpression,
    if_exp: IfExpression,
    pub fn format(self: Expression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            inline else => |item| try writer.print("{}", .{item}),
        }
    }
};

pub const LetStatement = struct {
    identifier: Identifier = undefined,
    value: Expression = undefined,
    pub fn format(
        self: LetStatement,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("let {} = {};", .{ self.identifier, self.value });
    }
};

pub const ReturnStatement = struct {
    value: Expression = undefined,
    pub fn format(self: ReturnStatement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("return {}", .{self.value});
    }
};
pub const ExpressionStatement = struct {
    expression: Expression = undefined,
    pub fn format(self: ExpressionStatement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.expression});
    }
};

pub const Identifier = struct {
    name: []const u8 = undefined,
    pub fn format(self: Identifier, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(self.name);
    }
};

pub const IntegerLiteral = struct {
    value: i64 = undefined,
    pub fn format(self: IntegerLiteral, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};

pub const PrefixExpression = struct {
    operator: token.tokens = undefined,
    right: *const Expression = undefined,
    pub fn format(self: PrefixExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("({}{})", .{ self.operator, self.right });
    }
};

pub const InfixExpression = struct {
    operator: token.tokens = undefined,
    right: *const Expression = undefined,
    left: *const Expression = undefined,
    pub fn format(self: InfixExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("({} {} {})", .{ self.left, self.operator, self.right });
    }
};

pub const BooleanExpression = struct {
    value: bool,
    pub fn format(self: BooleanExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};
pub const IfExpression = struct {
    condition: *const Expression = undefined,
    consequence: *const BlockStatement = undefined,
    alternative: ?*const BlockStatement = undefined,
    pub fn format(self: IfExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("if{} {}", .{ self.condition, self.consequence });
        if (self.alternative) |alt| {
            try writer.print(" else {}", .{alt});
        }
    }
};

pub const BlockStatement = struct {
    statements: std.ArrayList(Statement),
    pub fn format(self: BlockStatement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("{ ");
        for (self.statements.items) |stmt| {
            try writer.print("{}", .{stmt});
        }
        try writer.writeAll(" }");
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),
    pub fn format(self: Program, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        for (self.statements.items) |stmt| {
            try writer.print("{}\n", .{stmt});
        }
    }
};
