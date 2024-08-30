const std = @import("std");
const token = @import("./token.zig");
const object = @import("object.zig");
const Object = object.Object;

const TRUE = &object.Boolean{ .value = true };
const FALSE = &object.Boolean{ .value = false };
const NULL = &object.Null{};

pub fn getNativeBooleanValue(val: bool) *const object.Boolean {
    if (val) {
        return TRUE;
    } else {
        return FALSE;
    }
}

pub const Statement = union(enum) {
    let: LetStatement,
    return_stmt: ReturnStatement,
    expression_stmt: ExpressionStatement,
    block_stmt: BlockStatement,
    Program: Program,
    pub fn format(self: Statement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            inline else => |item| try writer.print("{}", .{item}),
        }
    }
    pub fn eval(self: Statement, alloc: *std.mem.Allocator) !Object {
        std.debug.print("stmt: {}\n", .{self});
        return switch (self) {
            .expression_stmt => |item| try item.eval(alloc),
            else => Object{ .Null = NULL },
        };
    }
};

pub const Expression = union(enum) {
    identifier: Identifier,
    integer: IntegerLiteral,
    prefix_exp: PrefixExpression,
    infix_exp: InfixExpression,
    boolean_exp: BooleanExpression,
    if_exp: IfExpression,
    fn_literal: FunctionLiteral,
    call_exp: CallExpressin,
    pub fn format(self: Expression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            inline else => |item| try writer.print("{}", .{item}),
        }
    }
    pub fn eval(self: Expression, alloc: *std.mem.Allocator) !Object {
        return switch (self) {
            .integer => |item| try item.eval(alloc),
            .boolean_exp => |item| try item.eval(alloc),
            .prefix_exp => |item| try item.eval(alloc),
            .infix_exp => |item| try item.eval(alloc),
            .if_exp => |item| try item.eval(alloc),
            else => Object{ .Null = NULL },
        };
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
        try writer.print("let {} = {}", .{ self.identifier, self.value });
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
    pub fn eval(self: ExpressionStatement, alloc: *std.mem.Allocator) !Object {
        std.debug.print("expstmt: {}\n", .{self});
        return try self.expression.eval(alloc);
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
    pub fn eval(self: IntegerLiteral, alloc: *std.mem.Allocator) !Object {
        const intPtr = try alloc.create(object.Interger);
        intPtr.value = self.value;
        return Object{ .Interger = intPtr };
    }
};

pub const PrefixExpression = struct {
    operator: token.tokens = undefined,
    right: *const Expression = undefined,
    pub fn format(self: PrefixExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("({}{})", .{ self.operator, self.right });
    }
    pub fn eval(self: PrefixExpression, alloc: *std.mem.Allocator) anyerror!Object {
        const right = try self.right.eval(alloc);
        return switch (self.operator) {
            .bang => try evalBangOperator(right),
            .minus => try evalMinusOperator(alloc, right),
            else => Object{ .Null = NULL },
        };
    }
};

pub fn evalMinusOperator(alloc: *std.mem.Allocator, right: Object) !Object {
    return switch (right) {
        .Interger => |item| {
            const intPtr = try alloc.create(object.Interger);
            intPtr.value = -item.value;
            return Object{ .Interger = intPtr };
        },
        else => Object{ .Null = NULL },
    };
}

pub fn evalBangOperator(right: Object) !Object {
    return switch (right) {
        .Boolean => |item| Object{ .Boolean = getNativeBooleanValue(!item.value) },
        .Null => Object{ .Boolean = getNativeBooleanValue(true) },
        else => Object{ .Boolean = getNativeBooleanValue(false) },
    };
}

pub const InfixExpression = struct {
    operator: token.tokens = undefined,
    right: *const Expression = undefined,
    left: *const Expression = undefined,
    pub fn format(self: InfixExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("({} {} {})", .{ self.left, self.operator, self.right });
    }
    pub fn eval(self: InfixExpression, alloc: *std.mem.Allocator) anyerror!Object {
        const right = try self.right.eval(alloc);
        const left = try self.left.eval(alloc);
        if (object.isIntergerTag(right) and object.isIntergerTag(left)) {
            return try evalIntergerInfix(alloc, self.operator, left, right);
        } else {
            return Object{ .Null = NULL };
        }
    }
};

pub fn evalIntergerInfix(alloc: *std.mem.Allocator, operator: token.tokens, left: Object, right: Object) !Object {
    const rightValue = right.Interger.value;
    const leftValue = left.Interger.value;
    const intPtr = try alloc.create(object.Interger);
    switch (operator) {
        .plus => {
            intPtr.value = leftValue + rightValue;
            return Object{ .Interger = intPtr };
        },
        .minus => {
            intPtr.value = leftValue - rightValue;
            return Object{ .Interger = intPtr };
        },
        .slash => {
            intPtr.value = @divTrunc(leftValue, rightValue);
            return Object{ .Interger = intPtr };
        },
        .asterisk => {
            intPtr.value = leftValue * rightValue;
            return Object{ .Interger = intPtr };
        },
        .greaterThan => {
            return Object{ .Boolean = getNativeBooleanValue(leftValue > rightValue) };
        },
        .lesserThan => {
            return Object{ .Boolean = getNativeBooleanValue(leftValue < rightValue) };
        },
        .equal_to => {
            return Object{ .Boolean = getNativeBooleanValue(leftValue == rightValue) };
        },
        .not_equal_to => {
            return Object{ .Boolean = getNativeBooleanValue(leftValue != rightValue) };
        },
        else => {
            alloc.destroy(intPtr);
            return Object{ .Null = NULL };
        },
    }
}

pub const BooleanExpression = struct {
    value: bool,
    pub fn format(self: BooleanExpression, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
    pub fn eval(self: BooleanExpression, _: *std.mem.Allocator) !Object {
        return Object{ .Boolean = getNativeBooleanValue(self.value) };
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
    pub fn eval(self: IfExpression, alloc: *std.mem.Allocator) anyerror!Object {
        const conditionValue = try self.condition.eval(alloc);
        if (object.isTruthy(conditionValue)) {
            return try self.consequence.eval(alloc);
        } else if (self.alternative) |alt| {
            return try alt.eval(alloc);
        } else {
            return Object{ .Null = NULL };
        }
    }
};

pub const BlockStatement = struct {
    statements: std.ArrayList(Statement),
    pub fn format(self: BlockStatement, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("{");
        for (self.statements.items) |stmt| {
            try writer.print("{}", .{stmt});
        }
        try writer.writeAll("}");
    }
    pub fn eval(self: BlockStatement, alloc: *std.mem.Allocator) !Object {
        const res = try alloc.create(Object);
        res.* = Object{ .Null = NULL };
        for (self.statements.items) |statement| {
            res.* = try statement.eval(alloc);
        }
        std.debug.print("block stmt loop: {} \n", .{res.*});
        return res.*;
    }
};

pub const FunctionLiteral = struct {
    token: token.tokens,
    parameters: std.ArrayList(Identifier),
    body: *const BlockStatement,
    pub fn format(self: FunctionLiteral, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}(", .{self.token});
        for (self.parameters.items, 1..) |stmt, index| {
            if (index == self.parameters.items.len) {
                try writer.print("{})", .{stmt});
            } else {
                try writer.print("{},", .{stmt});
            }
        }
        try writer.print("{}", .{self.body});
    }
};

pub const CallExpressin = struct {
    function: *const Expression,
    arguments: std.ArrayList(Expression),
    pub fn format(self: CallExpressin, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}(", .{self.function});
        for (self.arguments.items, 1..) |stmt, index| {
            if (index == self.arguments.items.len) {
                try writer.print("{})", .{stmt});
            } else {
                try writer.print("{},", .{stmt});
            }
        }
    }
};

pub const Program = struct {
    statements: std.ArrayList(Statement),
    pub fn format(self: Program, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        for (self.statements.items) |stmt| {
            try writer.print("{}\n", .{stmt});
        }
    }

    pub fn eval(self: Program, alloc: *std.mem.Allocator) !Object {
        const res = try alloc.create(Object);
        res.* = Object{ .Null = NULL };
        for (self.statements.items) |statement| {
            res.* = try statement.eval(alloc);
        }
        std.debug.print("stmt loop: {} \n", .{res.*});
        return res.*;
    }
};
