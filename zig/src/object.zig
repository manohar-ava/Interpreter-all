const std = @import("std");
const Parser = @import("./parser.zig");
const Lexer = @import("./lexer.zig");
const ast = @import("./abstract_syntax_tree.zig");
const evaluator = @import("evaluator.zig");
const environment = @import("environment.zig");
const testing = std.testing;

pub const Object = union(enum) {
    Interger: *const Interger,
    Boolean: *const Boolean,
    Null: *const Null,
    Return: *const Return,
    Error: *const Error,
    Function: *const Function,
    pub fn format(self: Object, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            inline else => |item| try writer.print("{}", .{item}),
        }
    }
    pub fn getType(self: Object) []const u8 {
        return switch (self) {
            .Interger => "INT",
            .Boolean => "BOOL",
            inline else => "",
        };
    }
};
pub fn isSameTag(ob1: Object, ob2: Object) bool {
    return @as(std.meta.Tag(Object), ob1) == @as(std.meta.Tag(Object), ob2);
}

pub fn isIntergerTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Interger = undefined });
}

pub fn isReturnTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Return = undefined });
}

pub fn isErrorTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Error = undefined });
}

pub fn isTruthy(ob: Object) bool {
    return switch (ob) {
        .Boolean => |item| item.value,
        .Null => false,
        else => true,
    };
}

pub const Return = struct {
    value: Object,
    pub fn format(self: Return, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};

pub const Interger = struct {
    value: i64,
    pub fn format(self: Interger, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};
pub const Boolean = struct {
    value: bool,
    pub fn format(self: Boolean, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};

pub const Null = struct {
    value: []const u8 = "null",
    pub fn format(_: Null, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("null");
    }
};

pub const Function = struct {
    parameters: std.ArrayList(ast.Identifier),
    body: *const ast.BlockStatement,
    env: *environment,
    pub fn format(self: Function, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("func(", .{});
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

pub const Error = struct {
    value: []const u8,
    pub fn format(self: Error, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(self.value);
    }
};

pub fn newError(alloc: *std.mem.Allocator, comptime format: []const u8, args: anytype) !Object {
    const message = try std.fmt.allocPrint(alloc.*, format, args);
    const error_obj = try alloc.create(Error);
    error_obj.* = .{ .value = message };
    return Object{ .Error = error_obj };
}

pub fn testEval(allocator: *std.mem.Allocator, input: []const u8) !?Object {
    const lex = try Lexer.newLexer(allocator, input);
    defer allocator.destroy(lex);
    var parser = try Parser.newParser(allocator, lex);
    const program = try parser.parse();
    var env = try environment.newEnv(allocator);
    defer env.deinit();
    return try evaluator.evaluate(allocator, program, &env);
}

test "test return evaluation" {
    const inputs: [7][]const u8 = .{
        "if(true){if(true){return 5} return 10}",
        "if(true){if(false){return 5} return 10}",
        "return 1;if(true){if(false){return 5} return 10}",
        "return 10;",
        "return 10; 9;",
        "return 2 * 5; 9;",
        "9; return 2 * 5; 9;",
    };
    const expected = [7]i64{ 5, 10, 1, 10, 10, 10, 10 };
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        if (evalValue) |e| {
            try std.testing.expect(e.Interger.value == expected[i]);
        }
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}

test "test condition evaluation" {
    const inputs: [4][]const u8 = .{
        "if(true){10}",
        "if(false){10}",
        "if(true){10}else{5}",
        "if(false){10}else{5}",
    };
    const expected = [4]?i64{ 10, null, 10, 5 };
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        if (evalValue) |e| {
            try std.testing.expect(e.Interger.value == expected[i]);
        }
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}

test "test int evaluation" {
    const inputs: [7][]const u8 = .{
        "10",
        "-5",
        "5 + 10;",
        "5 + 5 + 5 + 5 - 10",
        "-50 + 100 + -50",
        "50 / 2 * 2 + 10",
        "(5 + 10 * 2 + 15 / 3) * 2 + -10",
    };
    const expected = [7]i64{ 10, -5, 15, 10, 0, 60, 50 };
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        const intValue = switch (evalValue.?) {
            .Interger => |item| item.value,
            else => @panic("int test failed"),
        };
        try std.testing.expect(intValue == expected[i]);
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}

test "test boolean evaluation" {
    const inputs: [13][]const u8 = .{
        "false",
        "true",
        "!false;",
        "!true",
        "!!false;",
        "!!true",
        "!!!false;",
        "!!!true",
        "!10",
        "1>0",
        "2<1",
        "1==1",
        "1!=1",
    };
    const expected = [13]bool{ false, true, true, false, false, true, true, false, false, true, false, true, false };
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        const boolValue = switch (evalValue.?) {
            .Boolean => |item| item.value,
            else => @panic("boolean test failed"),
        };
        try std.testing.expect(boolValue == expected[i]);
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}

test "test errors for eval" {
    const inputs: [5][]const u8 = .{
        "-true;",
        "3+false",
        "true+false",
        "if(10<12){true - false} return 10;",
        "if(10<12){if(true){false+1}} return 10;",
    };
    const expected: [5][]const u8 = .{
        "Invalid Type: -BOOL",
        "Type Mismatch: INT + BOOL",
        "Unknown Operator: BOOL + BOOL",
        "Unknown Operator: BOOL - BOOL",
        "Type Mismatch: BOOL + INT",
    };
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        const errVal = switch (evalValue.?) {
            .Error => |item| item.value,
            else => @panic("error test failed"),
        };
        try std.testing.expect(std.mem.eql(u8, errVal, expected[i]));
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}
test "test env" {
    const inputs: [5][]const u8 = .{
        "let x = 1+3; return x;",
        "let a = 5; a;",
        "let a = 5 * 5; a;",
        "let a = 5; let b = a; b;",
        "let a = 5; let b = a; let c = a + b + 5; c;",
    };
    const expected: [5]i64 = .{ 4, 5, 25, 5, 15 };
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        const intVal = switch (evalValue.?) {
            .Interger => |item| item.value,
            else => @panic("env test failed"),
        };
        try std.testing.expect(intVal == expected[i]);
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}

test "test functions" {
    const inputs: [1][]const u8 = .{
        "let double = func(x){ x * 2 }; double(10)",
    };
    const expected: [1]i64 = .{10};
    for (inputs, 0..) |input, i| {
        std.debug.print("--------------------------------------------- \n", .{});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, input);
        _ = i;
        _ = expected;
        std.debug.print("{any}\n", .{evalValue});
        // const intVal = switch (evalValue.?) {
        //     .Interger => |item| item.value,
        //     else => @panic("env test failed"),
        // };
        // try std.testing.expect(intVal == expected[i]);
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}
