const std = @import("std");
const Parser = @import("./parser.zig");
const Lexer = @import("./lexer.zig");
const ast = @import("./abstract_syntax_tree.zig");
const String = @import("string.zig").String;
const environment = @import("environment.zig");
const evaluator = @import("evaluator.zig");
const testing = std.testing;

pub const Object = union(enum) {
    Integer: Integer,
    Boolean: Boolean,
    Null: Null,
    Return: Return,
    Error: Error,
    pub fn getType(self: Object) []const u8 {
        return switch (self) {
            .Integer => "INT",
            .Boolean => "BOOL",
            inline else => "unknown type",
        };
    }
    pub fn stringValue(self: *const Object, buf: *String) !void {
        return switch (self.*) {
            inline else => |item| try item.stringValue(buf),
        };
    }
};
pub fn isSameTag(ob1: *Object, ob2: *Object) bool {
    return @as(std.meta.Tag(Object), ob1.*) == @as(std.meta.Tag(Object), ob2.*);
}

pub fn isIntegerTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Integer = undefined });
}

pub fn isReturnTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Return = undefined });
}

pub fn isErrorTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Error = undefined });
}

// pub fn isFunctionTag(ob: Object) bool {
//     return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Function = undefined });
// }

pub fn isTruthy(ob: *Object) bool {
    return switch (ob.*) {
        .Boolean => |item| item.value,
        .Null => false,
        else => true,
    };
}

pub const Return = struct {
    value: *Object,
    pub fn stringValue(self: *const Return, buf: *String) String.Error!void {
        try self.value.stringValue(buf);
    }
};

pub const Integer = struct {
    value: i64,
    pub fn stringValue(self: *const Integer, buf: *String) String.Error!void {
        const intString = try std.fmt.allocPrint(buf.allocator, "{}", .{self.value});
        try buf.concat(intString);
    }
};
pub const Boolean = struct {
    value: bool,
    pub fn stringValue(self: *const Boolean, buf: *String) String.Error!void {
        if (self.value) {
            try buf.concat("true");
        } else {
            try buf.concat("false");
        }
    }
};

pub const Null = struct {
    pub fn stringValue(_: Null, buf: *String) String.Error!void {
        try buf.concat("null");
    }
};

pub const Error = struct {
    value: []const u8,
    pub fn stringValue(self: *const Error, buf: *String) String.Error!void {
        try buf.concat("Error: ");
        try buf.concat(self.value);
    }
};

pub fn newError(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !*Object {
    const message = try std.fmt.allocPrint(allocator, fmt, args);
    const errorPtr = try allocator.create(Object);
    errorPtr.* = Object{ .Error = Error{ .value = message } };
    return errorPtr;
}
pub fn newInteger(allocator: std.mem.Allocator, value: i64) !*Object {
    const integerPtr = try allocator.create(Object);
    integerPtr.* = Object{
        .Integer = Integer{ .value = value },
    };
    return integerPtr;
}

pub fn testEval(allocator: *std.mem.Allocator, input: []const u8) !*Object {
    const lex = try Lexer.newLexer(allocator, input);
    var parser = try Parser.newParser(allocator, lex);
    const program = try parser.parse();
    var env = environment.Environment.new(allocator.*);
    return try evaluator.evaluate(allocator.*, program, &env);
}

const TestType = struct {
    input: []const u8,
    expected: []const u8,
};

test "test return evaluation" {
    const tests: [7]TestType = [_]TestType{
        .{ .input = "if(true){if(true){return 5} return 10}", .expected = "5" },
        .{ .input = "if(true){if(false){return 5} return 10}", .expected = "10" },
        .{ .input = "return 1;if(true){if(false){return 5} return 10}", .expected = "1" },
        .{ .input = "return 10;", .expected = "10" },
        .{ .input = "return 10; 9;", .expected = "10" },
        .{ .input = "return 2 * 5; 9;", .expected = "10" },
        .{ .input = "9; return 2 * 5; 9;", .expected = "10" },
    };
    for (tests) |t| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, t.input);
        var printBuf = String.init(allocator);
        try evalValue.stringValue(&printBuf);
        try std.testing.expect(std.mem.eql(u8, t.expected, printBuf.str()));
    }
}

test "test condition evaluation" {
    const tests: [4]TestType = [_]TestType{
        .{ .input = "if(true){10}", .expected = "10" },
        .{ .input = "if(false){10}", .expected = "null" },
        .{ .input = "if(true){10}else{5}", .expected = "10" },
        .{ .input = "if(false){10}else{5}", .expected = "5" },
    };
    for (tests) |t| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, t.input);
        var printBuf = String.init(allocator);
        try evalValue.stringValue(&printBuf);
        try std.testing.expect(std.mem.eql(u8, t.expected, printBuf.str()));
    }
}

test "test int evaluation" {
    const tests: [7]TestType = [_]TestType{
        .{ .input = "10", .expected = "10" },
        .{ .input = "-5", .expected = "-5" },
        .{ .input = "5 + 10;", .expected = "15" },
        .{ .input = "5 + 5 + 5 + 5 - 10", .expected = "10" },
        .{ .input = "-50 + 100 + -50", .expected = "0" },
        .{ .input = "50 / 2 * 2 + 10", .expected = "60" },
        .{ .input = "(5 + 10 * 2 + 15 / 3) * 2 + -10", .expected = "50" },
    };
    for (tests) |t| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, t.input);
        var printBuf = String.init(allocator);
        try evalValue.stringValue(&printBuf);
        try std.testing.expect(std.mem.eql(u8, t.expected, printBuf.str()));
    }
}

test "test boolean evaluation" {
    const tests: [13]TestType = [_]TestType{
        .{ .input = "false", .expected = "false" },
        .{ .input = "true", .expected = "true" },
        .{ .input = "!false;", .expected = "true" },
        .{ .input = "!true", .expected = "false" },
        .{ .input = "!!false;", .expected = "false" },
        .{ .input = "!!true", .expected = "true" },
        .{ .input = "!!!false;", .expected = "true" },
        .{ .input = "!!!true", .expected = "false" },
        .{ .input = "!10", .expected = "false" },
        .{ .input = "1>0", .expected = "true" },
        .{ .input = "2<1", .expected = "false" },
        .{ .input = "1==1", .expected = "true" },
        .{ .input = "1!=1", .expected = "false" },
    };
    for (tests) |t| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, t.input);
        var printBuf = String.init(allocator);
        try evalValue.stringValue(&printBuf);
        try std.testing.expect(std.mem.eql(u8, t.expected, printBuf.str()));
    }
}

test "test errors for eval" {
    const tests: [5]TestType = [_]TestType{
        .{ .input = "-true;", .expected = "Error: Invalid Type: -BOOL" },
        .{ .input = "3+false", .expected = "Error: Type Mismatch: INT + BOOL" },
        .{ .input = "true+false", .expected = "Error: Unknown Operator: BOOL + BOOL" },
        .{ .input = "if(10<12){true - false} return 10;", .expected = "Error: Unknown Operator: BOOL - BOOL" },
        .{ .input = "if(10<12){if(true){false+1}} return 10;", .expected = "Error: Type Mismatch: BOOL + INT" },
    };
    for (tests) |t| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, t.input);
        var printBuf = String.init(allocator);
        try evalValue.stringValue(&printBuf);
        try std.testing.expect(std.mem.eql(u8, t.expected, printBuf.str()));
    }
}
test "test env" {
    const tests: [5]TestType = [_]TestType{
        .{ .input = "let x = 1+3; return x;", .expected = "4" },
        .{ .input = "let a = 5; a;", .expected = "5" },
        .{ .input = "let a = 5 * 5; a;", .expected = "25" },
        .{ .input = "let a = 5; let b = a; b;", .expected = "5" },
        .{ .input = "let a = 5; let b = a; let c = a + b + 5; c;", .expected = "15" },
    };
    for (tests) |t| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var allocator = arena.allocator();
        const evalValue = try testEval(&allocator, t.input);
        var printBuf = String.init(allocator);
        try evalValue.stringValue(&printBuf);
        try std.testing.expect(std.mem.eql(u8, t.expected, printBuf.str()));
    }
}
//
// test "test functions and closures" {
//     const inputs: [6][]const u8 = .{
//         "let double = func(x){ x * 2 }; double(10)",
//         "let triple = func(x){ return x * 3; }; triple(10)",
//         "let add = func(x,y){ x + y }; add(1+1,3+1)",
//         "let add = func(x,y){ x + y }; add(1+1,add(10,10))",
//         "let add = func(x,y){ x + y }; let prod = func(x,y){ x * y }; prod(add(1,1),prod(2,2));",
//         //test for closure
//         "let multiplier = func(x){ func(y){x * y}; }; let twoMultiplier = multiplier(2); twoMultiplier(8);",
//     };
//     const expected: [6]i64 = .{ 20, 30, 6, 22, 8, 16 };
//     for (inputs, 0..) |input, i| {
//         std.debug.print("--------------------------------------------- \n", .{});
//         var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//         defer arena.deinit();
//         var allocator = arena.allocator();
//         const evalValue = try testEval(&allocator, input);
//         const intVal = switch (evalValue.?) {
//             .Integer => |item| item.value,
//             else => @panic("func test failed"),
//         };
//         try std.testing.expect(intVal == expected[i]);
//         std.debug.print("--------------------------------------------- \n", .{});
//     }
//     std.debug.print("============================================= \n", .{});
// }
//
// test "test closures" {
//     const inputs: [3][]const u8 = .{
//         "let multiplier = func(x){ func(y){x * y}; };",
//         "let twoMultiplier = multiplier(2);",
//         "twoMultiplier(8);",
//     };
//     const expected: [6]i64 = .{ 20, 30, 6, 22, 8, 16 };
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     var allocator = arena.allocator();
//     const env = try environment.newEnv(&allocator);
//     for (inputs, 0..) |input, i| {
//         std.debug.print("--------------------------------------------- \n", .{});
//         const lex = try Lexer.newLexer(&allocator, input);
//         var parser = try Parser.newParser(&allocator, lex);
//         const program = try parser.parse();
//         const evalValue = evaluator.evaluate(&allocator, program, env);
//         std.debug.print("{any} \n", .{evalValue});
//         _ = i;
//         _ = expected;
//         // const intVal = switch (evalValue.?) {
//         //     .Integer => |item| item.value,
//         //     else => @panic("func test failed"),
//         // };
//         // try std.testing.expect(intVal == expected[i]);
//         std.debug.print("--------------------------------------------- \n", .{});
//     }
//     std.debug.print("============================================= \n", .{});
// }
