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
    while_stmt: WhileStatement,
    break_stmt: BreakStatement,
    continue_stmt: ContinueStatement,
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
    string_literal: StringLiteral,
    array_literal: ArrayLiteral,
    index_exp: IndexExpression,
    hash_literal: HashLiteral,
    assignment: AssignStatement,
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

pub const AssignStatement = struct {
    identifier: Identifier = undefined,
    value: *Expression = undefined,
    pub fn stringValue(self: AssignStatement, buf: *String) String.Error!void {
        try self.identifier.stringValue(buf);
        try buf.concat(" = ");
        try self.value.stringValue(buf);
    }
    pub fn eval(self: AssignStatement, alloc: std.mem.Allocator, env: *environment) !*Object {
        try env.insert(self.identifier.name, try self.value.eval(alloc, env));
        return &inbuilt.NULL_OBJECT;
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
        }
        if (inbuilt.getInBuiltFnRef(self.name)) |inBuiltFnRef| {
            return inBuiltFnRef;
        }
        return object.newError(alloc, "Unknown Identifier: {s}", .{self.name});
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

pub const StringLiteral = struct {
    value: []const u8 = undefined,
    pub fn stringValue(self: StringLiteral, buf: *String) String.Error!void {
        try buf.concat("\"");
        try buf.concat(self.value);
        try buf.concat("\"");
    }
    pub fn eval(self: StringLiteral, alloc: std.mem.Allocator, _: *environment) !*Object {
        return try object.newString(alloc, self.value);
    }
};
pub const ArrayLiteral = struct {
    elements: std.ArrayList(Expression),
    pub fn stringValue(self: ArrayLiteral, buf: *String) String.Error!void {
        try buf.concat("[");
        for (self.elements.items, 1..) |ele, index| {
            try ele.stringValue(buf);
            if (index < self.elements.items.len) {
                try buf.concat(", ");
            }
        }
        try buf.concat("]");
    }
    pub fn eval(self: ArrayLiteral, alloc: std.mem.Allocator, env: *environment) !*Object {
        var elementsOb = std.ArrayList(*Object).init(alloc);
        for (self.elements.items) |ele| {
            const evaled = try ele.eval(alloc, env);
            switch (evaled.*) {
                .Error => return evaled,
                else => {},
            }
            try elementsOb.append(evaled);
        }
        return object.newArray(alloc, elementsOb);
    }
};

pub const IndexExpression = struct {
    left: *Expression,
    index: *Expression,
    pub fn stringValue(self: IndexExpression, buf: *String) String.Error!void {
        try buf.concat("(");
        try self.left.stringValue(buf);
        try buf.concat("[");
        try self.index.stringValue(buf);
        try buf.concat("])");
    }
    pub fn eval(self: *const IndexExpression, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        const leftVal = try self.left.eval(alloc, env);
        const index = try self.index.eval(alloc, env);
        return switch (leftVal.*) {
            .ArrayLiteral => |*arr| switch (index.*) {
                .Integer => |*int| try evalArrayIndexExpression(arr, int),
                else => object.newError(
                    alloc,
                    "evaluated index type expected:INTEGER , got:{s}",
                    .{index.getType()},
                ),
            },
            .HashLiteral => |*hash| {
                const hashKey = convertToHashableFromObject(index.*);
                if (hashKey) |key| {
                    if (hash.*.get(key)) |value| {
                        return value;
                    } else {
                        return &inbuilt.NULL_OBJECT;
                    }
                } else {
                    return try object.newError(alloc, "unusable as hash key: {s}", .{index.getType()});
                }
            },
            else => object.newError(alloc, "Cannot index on type: {s}", .{leftVal.getType()}),
        };
    }
};

fn convertToHashableFromObject(obj: object.Object) ?object.HashableObject {
    switch (obj) {
        .Integer => |integer| return object.HashableObject{ .integer = integer },
        .Boolean => |boolean| return object.HashableObject{ .boolean = boolean },
        .StringLiteral => |str| return object.HashableObject{ .string = str },
        else => return null,
    }
}

pub const HashLiteral = struct {
    pairs: std.ArrayList(HashPair),
    pub fn stringValue(self: HashLiteral, buf: *String) String.Error!void {
        try buf.concat("{");
        for (self.pairs.items, 1..) |pair, i| {
            try pair.stringValue(buf);
            if (i == self.pairs.items.len) {
                try buf.concat("}");
            } else {
                try buf.concat(",");
            }
        }
    }
    pub fn eval(self: *const HashLiteral, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        var pairs = object.HashLiteral.HashMap.init(alloc);
        for (self.pairs.items) |pair| {
            const key = try pair.key.eval(alloc, env);
            switch (key.*) {
                .Error => return key,
                else => {},
            }
            const value = try pair.value.eval(alloc, env);
            switch (value.*) {
                .Error => return value,
                else => {},
            }
            try pairs.put(object.HashableObject.fromObject(key.*), value);
        }
        const objectPtr = try alloc.create(object.Object);
        objectPtr.* = object.Object{
            .HashLiteral = .{ .pairs = pairs },
        };
        return objectPtr;
    }
};

pub const HashPair = struct {
    key: Expression,
    value: Expression,
    pub fn stringValue(self: *const HashPair, buf: *String) String.Error!void {
        try self.key.stringValue(buf);
        try buf.concat(":");
        try self.value.stringValue(buf);
    }
};

fn evalArrayIndexExpression(array: *object.ArrayLiteral, index: *object.Integer) !*Object {
    const arrayLength = array.elements.items.len;
    if (index.value < 0 or index.value >= arrayLength) {
        return &inbuilt.NULL_OBJECT;
    }
    const idx: usize = @intCast(index.value);
    return array.elements.items[idx];
}

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
            .StringLiteral => evalStringInfix(alloc, self.operator, left, right),
            inline else => object.newError(alloc, "Unknown Operator: {s} {s} {s}", .{
                left.getType(),
                self.operator.toString(),
                right.getType(),
            }),
        };
    }
};

pub fn evalStringInfix(
    alloc: std.mem.Allocator,
    operator: token.tokens,
    left: *const Object,
    right: *const Object,
) !*Object {
    const rightValue = switch (right.*) {
        .StringLiteral => |item| item.value,
        else => @panic("not a string"),
    };
    const leftValue = switch (left.*) {
        .StringLiteral => |item| item.value,
        else => @panic("not a string"),
    };
    return switch (operator) {
        .plus => {
            const slices = &[_][]const u8{ leftValue, rightValue };
            const combined = try std.mem.concat(alloc, u8, slices);
            const objectPtr = try alloc.create(Object);
            objectPtr.* = Object{
                .StringLiteral = object.StringLiteral{ .value = combined },
            };
            return objectPtr;
        },
        else => object.newError(alloc, "Unknown Operator: {s} {s} {s}", .{
            left.getType(),
            operator.toString(),
            right.getType(),
        }),
    };
}

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
        for (self.statements.items) |stmt| {
            try stmt.stringValue(buf);
        }
        try buf.concat(" }");
    }
    pub fn eval(self: *const BlockStatement, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        var result: *object.Object = &inbuilt.NULL_OBJECT;
        for (self.statements.items) |stmt| {
            const evaled = try stmt.eval(alloc, env);
            if (object.isReturnTag(evaled.*) or object.isErrorTag(evaled.*) or
                evaled == &inbuilt.BREAK_OBJECT or evaled == &inbuilt.CONTINUE_OBJECT)
            {
                return evaled;
            }
            result = evaled;
        }
        return result;
    }
};

pub const WhileStatement = struct {
    condition: *Expression = undefined,
    whileBlock: BlockStatement = undefined,
    pub fn stringValue(self: WhileStatement, buf: *String) String.Error!void {
        try buf.concat("while ");
        try self.condition.stringValue(buf);
        try buf.concat(" ");
        try self.whileBlock.stringValue(buf);
    }
    pub fn eval(self: *const WhileStatement, alloc: std.mem.Allocator, env: *environment) anyerror!*Object {
        while (true) {
            const condition = try self.condition.eval(alloc, env);
            if (object.isErrorTag(condition.*)) {
                return condition;
            }
            if (object.isTruthy(condition)) {
                const evaled = try self.whileBlock.eval(alloc, env);
                if (object.isErrorTag(evaled.*) or object.isReturnTag(evaled.*)) {
                    return evaled;
                }
                if (evaled == &inbuilt.BREAK_OBJECT) {
                    break;
                }
                if (evaled == &inbuilt.CONTINUE_OBJECT) {
                    continue;
                }
            } else {
                break;
            }
        }
        const result: *object.Object = &inbuilt.NULL_OBJECT;
        return result;
    }
};

pub const BreakStatement = struct {
    token: token.tokens = undefined,
    pub fn stringValue(self: BreakStatement, buf: *String) String.Error!void {
        _ = try self.token.stringValue(buf);
    }
    pub fn eval(_: *const BreakStatement, _: std.mem.Allocator, _: *environment) anyerror!*Object {
        return &inbuilt.BREAK_OBJECT;
    }
};

pub const ContinueStatement = struct {
    token: token.tokens = undefined,
    pub fn stringValue(self: ContinueStatement, buf: *String) String.Error!void {
        _ = try self.token.stringValue(buf);
    }
    pub fn eval(_: *const ContinueStatement, _: std.mem.Allocator, _: *environment) anyerror!*Object {
        return &inbuilt.CONTINUE_OBJECT;
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
    return switch (function.*) {
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
        .InBuiltFunction => |func| try func.call(alloc, arguments),
        else => @panic("not a func"),
    };
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
