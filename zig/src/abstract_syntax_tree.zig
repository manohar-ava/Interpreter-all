const std = @import("std");
const token = @import("./token.zig");
const String = @import("string.zig").String;
const inbuilt = @import("inbuilt.zig");
const object = @import("object.zig");
const Object = object.Object;
const ENV = @import("environment.zig");
const environment = ENV.Environment;

pub const Statement = union(enum) {
    let: LetStatement,
    return_stmt: ReturnStatement,
    expression_stmt: ExpressionStatement,
    block_stmt: BlockStatement,
    pub fn stringValue(self: *const Statement, buf: *String) !void {
        return switch (self.*) {
            inline else => |item| try item.stringValue(buf),
        };
    }
    pub fn eval(self: Statement, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        return switch (self) {
            inline else => |item| try item.eval(alloc, env),
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
    call_exp: callExpression,
    pub fn stringValue(self: *const Expression, buf: *String) !void {
        return switch (self.*) {
            inline else => |item| try item.stringValue(buf),
        };
    }
    pub fn eval(self: Expression, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        return switch (self) {
            inline else => |item| try item.eval(alloc, env),
        };
    }
};

pub const LetStatement = struct {
    identifier: Identifier = undefined,
    value: *Expression = undefined,
    pub fn stringValue(self: LetStatement, buf: *String) String.Error!void {
        try buf.concat("let ");
        try self.identifier.stringValue(buf);
        try buf.concat(" = ");
        try self.value.stringValue(buf);
    }
    pub fn eval(self: LetStatement, alloc: std.mem.Allocator, env: *environment) !*Object {
        try env.insert(self.identifier.name, try self.value.eval(alloc, env));
        return &inbuilt.NULL_OBJECT;
    }
};

pub const ReturnStatement = struct {
    value: *Expression = undefined,
    pub fn stringValue(self: ReturnStatement, buf: *String) String.Error!void {
        try buf.concat("return ");
        try self.value.stringValue(buf);
    }
    pub fn eval(self: ReturnStatement, alloc: std.mem.Allocator, env: *environment) !*Object {
        const returnPtr = try alloc.create(Object);
        returnPtr.* = .{ .Return = .{ .value = try self.value.eval(alloc, env) } };
        return returnPtr;
    }
};
pub const ExpressionStatement = struct {
    expression: *Expression = undefined,
    pub fn stringValue(self: ExpressionStatement, buf: *String) String.Error!void {
        try self.expression.stringValue(buf);
    }
    pub fn eval(self: ExpressionStatement, alloc: std.mem.Allocator, env: *environment) !*Object {
        return try self.expression.eval(alloc, env);
    }
};

pub const Identifier = struct {
    name: []const u8 = undefined,
    pub fn stringValue(self: Identifier, buf: *String) String.Error!void {
        try buf.concat(self.name);
    }
    pub fn eval(self: Identifier, alloc: std.mem.Allocator, env: *environment) !*Object {
        if (env.get(self.name)) |item| {
            return item;
        } else {
            return object.newError(alloc, "Unknown Identifier: {s}", .{self.name});
        }
    }
};

pub const IntegerLiteral = struct {
    value: i64 = undefined,
    pub fn stringValue(self: IntegerLiteral, buf: *String) String.Error!void {
        const intString = try std.fmt.allocPrint(buf.allocator, "{}", .{self.value});
        try buf.concat(intString);
    }
    pub fn eval(self: IntegerLiteral, alloc: std.mem.Allocator, _: *environment) !*Object {
        return try object.newInteger(alloc, self.value);
    }
};

pub const PrefixExpression = struct {
    operator: token.tokens = undefined,
    right: *Expression = undefined,
    pub fn stringValue(self: PrefixExpression, buf: *String) String.Error!void {
        try buf.concat("(");
        try self.operator.stringValue(buf);
        try self.right.stringValue(buf);
        try buf.concat(")");
    }
    pub fn eval(self: *const PrefixExpression, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        const right = try self.right.eval(alloc, env);
        return switch (self.operator) {
            .bang => evalBangOperator(right),
            .minus => try evalMinusOperator(alloc, right),
            else => &inbuilt.NULL_OBJECT,
        };
    }
};

fn nativeBoolToBooleanObject(native: bool) *object.Object {
    if (native) {
        return &inbuilt.TRUE_OBJECT;
    } else {
        return &inbuilt.FALSE_OBJECT;
    }
}

pub fn evalMinusOperator(alloc: std.mem.Allocator, right: *Object) !*Object {
    return switch (right.*) {
        .Integer => |item| {
            return try object.newInteger(alloc, -item.value);
        },
        else => object.newError(alloc, "Invalid Type: -{s}", .{right.getType()}),
    };
}

fn evalBangOperator(right: *object.Object) *object.Object {
    switch (right.*) {
        .Boolean => |boolean| {
            if (boolean.value) {
                return &inbuilt.FALSE_OBJECT;
            } else {
                return &inbuilt.TRUE_OBJECT;
            }
        },
        .Null => return &inbuilt.TRUE_OBJECT,
        else => return &inbuilt.FALSE_OBJECT,
    }
}

pub const InfixExpression = struct {
    operator: token.tokens = undefined,
    right: *Expression = undefined,
    left: *Expression = undefined,
    pub fn stringValue(self: InfixExpression, buf: *String) String.Error!void {
        try buf.concat("(");
        try self.left.stringValue(buf);
        try buf.concat(" ");
        try self.operator.stringValue(buf);
        try buf.concat(" ");
        try self.right.stringValue(buf);
        try buf.concat(")");
    }
    pub fn eval(self: InfixExpression, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        const right = try self.right.eval(alloc, env);
        const left = try self.left.eval(alloc, env);
        if (!object.isSameTag(left, right)) {
            return object.newError(alloc, "Type Mismatch: {s} {s} {s}", .{
                left.getType(),
                self.operator.toString(),
                right.getType(),
            });
        }
        return switch (right.*) {
            .Integer => evalIntergerInfix(alloc, self.operator, left, right),
            inline else => object.newError(alloc, "Unknown Operator: {s} {s} {s}", .{
                left.getType(),
                self.operator.toString(),
                right.getType(),
            }),
        };
    }
};

pub fn evalIntergerInfix(
    alloc: std.mem.Allocator,
    operator: token.tokens,
    left: *const Object,
    right: *const Object,
) !*Object {
    const rightValue = switch (right.*) {
        .Integer => |item| item.value,
        else => @panic("not an int"),
    };
    const leftValue = switch (left.*) {
        .Integer => |item| item.value,
        else => @panic("not an int"),
    };
    return switch (operator) {
        .plus => try object.newInteger(alloc, leftValue + rightValue),
        .minus => try object.newInteger(alloc, leftValue - rightValue),
        .slash => try object.newInteger(alloc, @divTrunc(leftValue, rightValue)),
        .asterisk => try object.newInteger(alloc, leftValue * rightValue),
        .greaterThan => nativeBoolToBooleanObject(leftValue > rightValue),
        .lesserThan => nativeBoolToBooleanObject(leftValue < rightValue),
        .equal_to => nativeBoolToBooleanObject(leftValue == rightValue),
        .not_equal_to => nativeBoolToBooleanObject(leftValue != rightValue),
        else => {
            return &inbuilt.NULL_OBJECT;
        },
    };
}

pub const BooleanExpression = struct {
    value: bool,
    pub fn stringValue(self: BooleanExpression, buf: *String) String.Error!void {
        if (self.value) {
            try buf.concat("true");
        } else {
            try buf.concat("false");
        }
    }
    pub fn eval(self: BooleanExpression, _: std.mem.Allocator, _: *environment) !*Object {
        return nativeBoolToBooleanObject(self.value);
    }
};

pub const IfExpression = struct {
    condition: *Expression = undefined,
    consequence: BlockStatement = undefined,
    alternative: ?BlockStatement = undefined,
    pub fn stringValue(self: IfExpression, buf: *String) String.Error!void {
        try buf.concat("if ");
        try self.condition.stringValue(buf);
        try buf.concat(" ");
        try self.consequence.stringValue(buf);
        if (self.alternative) |*alt| {
            try buf.concat(" else ");
            try alt.stringValue(buf);
        }
    }
    pub fn eval(self: IfExpression, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        const conditionValue = try self.condition.eval(alloc, env);
        if (object.isTruthy(conditionValue)) {
            return try self.consequence.eval(alloc, env);
        } else if (self.alternative) |alt| {
            return try alt.eval(alloc, env);
        } else {
            return &inbuilt.NULL_OBJECT;
        }
    }
};

pub const BlockStatement = struct {
    statements: std.ArrayList(Statement),
    pub fn stringValue(self: BlockStatement, buf: *String) String.Error!void {
        try buf.concat("{ ");
        // var i: usize = 0;
        // while (i < self.statements.items.len) : (i += 1) {
        //     try self.statements.items[i].toString(buf);
        // }
        for (self.statements.items) |stmt| {
            try stmt.stringValue(buf);
        }
        try buf.concat(" }");
    }
    pub fn eval(self: *const BlockStatement, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        var result: *object.Object = &inbuilt.NULL_OBJECT;
        for (self.statements.items) |stmt| {
            const evaled = try stmt.eval(alloc, env);
            if (object.isReturnTag(evaled.*) or object.isErrorTag(evaled.*)) {
                return evaled;
            }
            result = evaled;
        }
        return result;
    }
};

pub const FunctionLiteral = struct {
    parameters: std.ArrayList(Identifier),
    body: BlockStatement,
    pub fn stringValue(self: FunctionLiteral, buf: *String) String.Error!void {
        try buf.concat("func(");
        for (self.parameters.items, 1..) |stmt, index| {
            try stmt.stringValue(buf);
            if (index == self.parameters.items.len) {
                try buf.concat(")");
            } else {
                try buf.concat(",");
            }
        }
        try self.body.stringValue(buf);
    }
    pub fn eval(self: *const FunctionLiteral, alloc: std.mem.Allocator, env: *environment) !*Object {
        return try object.newFunction(alloc, self.parameters, self.body, env);
    }
};

pub const callExpression = struct {
    function: *Expression,
    arguments: std.ArrayList(Expression),
    pub fn stringValue(self: callExpression, buf: *String) String.Error!void {
        try self.function.stringValue(buf);
        try buf.concat("(");
        for (self.arguments.items, 1..) |arg, index| {
            try arg.stringValue(buf);
            if (index == self.arguments.items.len) {
                try buf.concat(")");
            } else {
                try buf.concat(", ");
            }
        }
    }

    pub fn eval(
        self: callExpression,
        alloc: std.mem.Allocator,
        env: *environment,
    ) !*Object {
        const function = try self.function.eval(alloc, env);
        switch (function.*) {
            .Error => return function,
            else => {},
        }
        var args = std.ArrayList(*Object).init(alloc);
        for (self.arguments.items) |arg| {
            const evaled = try arg.eval(alloc, env);
            switch (evaled.*) {
                .Error => return evaled,
                else => {},
            }
            try args.append(evaled);
        }
        return try applyFunction(alloc, function, args);
    }
};

fn applyFunction(
    alloc: std.mem.Allocator,
    function: *Object,
    arguments: std.ArrayList(*Object),
) !*object.Object {
    switch (function.*) {
        .Function => |*func| {
            if (func.parameters.items.len != arguments.items.len) {
                return object.newError(
                    alloc,
                    "wrong number of arguments: want={}, got={}",
                    .{ func.parameters.items.len, arguments.items.len },
                );
            }
            const extendedEnv = try extendFunctionEnv(alloc, func, arguments);
            const evaluated = try func.body.eval(alloc, extendedEnv);
            return unwrapReturnValue(evaluated);
        },
        else => @panic("not a func"),
    }
}

fn unwrapReturnValue(obj: *Object) *Object {
    switch (obj.*) {
        .Return => |returnValue| return returnValue.value,
        else => return obj,
    }
}

fn extendFunctionEnv(
    alloc: std.mem.Allocator,
    function: *object.Function,
    arguments: std.ArrayList(*Object),
) anyerror!*environment {
    const envPtr = try alloc.create(environment);
    envPtr.* = environment.newEnclose(alloc, function.env);
    for (function.parameters.items, 0..) |param, i| {
        try envPtr.insert(param.name, arguments.items[i]);
    }

    return envPtr;
}

pub const Program = struct {
    statements: std.ArrayList(Statement),
    pub fn stringValue(self: Program, buf: *String) String.Error!void {
        for (self.statements.items) |stmt| {
            try stmt.stringValue(buf);
        }
    }
    pub fn eval(self: Program, alloc: std.mem.Allocator, env: *environment) !*Object {
        var result: *object.Object = &inbuilt.NULL_OBJECT;
        for (self.statements.items) |stmt| {
            const evaled = try stmt.eval(alloc, env);
            if (object.isReturnTag(evaled.*)) {
                return @constCast(evaled.Return.value);
            }
            if (object.isErrorTag(evaled.*)) {
                return evaled;
            }
            result = evaled;
        }
        return result;
    }
};
