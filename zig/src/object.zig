const std = @import("std");
const Parser = @import("./parser.zig");
const Lexer = @import("./lexer.zig");
const ast = @import("./abstract_syntax_tree.zig");
const String = @import("string.zig").String;
const environment = @import("environment.zig");
const evaluator = @import("evaluator.zig");
const inbuilt = @import("inbuilt.zig");
const testing = std.testing;

pub const Object = union(enum) {
    Integer: Integer,
    Boolean: Boolean,
    StringLiteral: StringLiteral,
    Null: Null,
    Return: Return,
    Error: Error,
    Function: Function,
    InBuiltFunction: InBuiltFunction,
    ArrayLiteral: ArrayLiteral,
    HashLiteral: HashLiteral,
    Break: Break,
    Continue: Continue,
    pub fn getType(self: Object) []const u8 {
        return switch (self) {
            .Integer => "INT",
            .Boolean => "BOOL",
            .StringLiteral => "STRING",
            .Null => "NULL",
            .Return => "RETURN",
            .Function => "FUNCTION",
            .InBuiltFunction => "INBUILTFUNC",
            .ArrayLiteral => "ARRAYLITERAL",
            .HashLiteral => "HASHLITERAL",
            .Break => "BREAK",
            .Continue => "CONTINUE",
            else => "Invalid Type",
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

pub const Break = struct {
    pub fn stringValue(_: *const Break, buf: *String) String.Error!void {
        try buf.concat("break");
    }
};

pub const Continue = struct {
    pub fn stringValue(_: *const Continue, buf: *String) String.Error!void {
        try buf.concat("continue");
    }
};

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

pub const StringLiteral = struct {
    value: []const u8,
    pub fn stringValue(self: *const StringLiteral, buf: *String) String.Error!void {
        try buf.concat(self.value);
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

pub const Function = struct {
    parameters: std.ArrayList(ast.Identifier),
    body: *const ast.BlockStatement,
    env: *environment.Environment,
    pub fn stringValue(self: *const Function, buf: *String) String.Error!void {
        try buf.concat("func");
        try buf.concat("(");
        for (self.parameters.items, 0..) |item, i| {
            try item.stringValue(buf);
            if (i != self.parameters.items.len - 1) {
                try buf.concat(",");
            }
        }
        try buf.concat(")");
    }
};

pub const InBuiltFunction = struct {
    function: inbuilt.InBuiltFunction,
    pub fn call(self: InBuiltFunction, allocator: std.mem.Allocator, args: std.ArrayList(*Object)) !*Object {
        return try self.function.call(allocator, args);
    }

    pub fn stringValue(self: InBuiltFunction, buf: *String) String.Error!void {
        try buf.concat("InBuiltFunction::");
        try buf.concat(@tagName(self.function));
    }
};

pub const ArrayLiteral = struct {
    elements: std.ArrayList(*Object),
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
};

pub const HashableObject = union(enum) {
    integer: Integer,
    boolean: Boolean,
    string: StringLiteral,

    pub fn fromObject(object: Object) HashableObject {
        return switch (object) {
            .Integer => |integer| .{ .integer = integer },
            .Boolean => |boolean| .{ .boolean = boolean },
            .StringLiteral => |str| .{ .string = str },
            else => unreachable,
        };
    }

    pub fn stringValue(self: HashableObject, buf: *String) String.Error!void {
        switch (self) {
            .integer => |integer| try integer.stringValue(buf),
            .boolean => |boolean| try boolean.stringValue(buf),
            .string => |str| try str.stringValue(buf),
        }
    }
};

pub const HashLiteral = struct {
    pub const HashMap = std.HashMap(
        HashableObject,
        *Object,
        HashContext,
        std.hash_map.default_max_load_percentage,
    );

    pub const HashContext = struct {
        pub fn eql(_: HashContext, obj1: HashableObject, obj2: HashableObject) bool {
            return switch (obj1) {
                .integer => |integer| switch (obj2) {
                    .integer => |integer2| integer.value == integer2.value,
                    else => false,
                },
                .boolean => |boolean| switch (obj2) {
                    .boolean => |boolean2| boolean.value == boolean2.value,
                    else => false,
                },
                .string => |str1| switch (obj2) {
                    .string => |str2| std.mem.eql(u8, str1.value, str2.value),
                    else => false,
                },
            };
        }

        pub fn hash(_: HashContext, obj: HashableObject) u64 {
            return switch (obj) {
                .integer => |integer| (std.hash_map.AutoContext(i64){}).hash(integer.value),
                .boolean => |boolean| (std.hash_map.AutoContext(bool){}).hash(boolean.value),
                .string => |str| (std.hash_map.StringContext{}).hash(str.value),
            };
        }
    };

    pairs: HashMap,

    pub fn get(self: HashLiteral, key: HashableObject) ?*Object {
        return self.pairs.get(key);
    }

    pub fn stringValue(self: HashLiteral, buf: *String) String.Error!void {
        try buf.concat("{");
        var it = self.pairs.iterator();
        const len = self.pairs.count();
        var i: usize = 0;
        while (it.next()) |pair| {
            try pair.key_ptr.*.stringValue(buf);
            try buf.concat(":");
            try pair.value_ptr.*.stringValue(buf);
            if (i != len - 1) {
                try buf.concat(", ");
            }
            i += 1;
        }
        try buf.concat("}");
    }
};

pub fn newFunction(
    allocator: std.mem.Allocator,
    parameters: std.ArrayList(ast.Identifier),
    body: ast.BlockStatement,
    env: *environment.Environment,
) !*Object {
    const functionPtr = try allocator.create(Object);
    const bodyPtr = try allocator.create(ast.BlockStatement);
    bodyPtr.* = ast.BlockStatement{ .statements = try body.statements.clone() };
    functionPtr.* = Object{
        .Function = Function{ .parameters = parameters, .body = bodyPtr, .env = env },
    };
    return functionPtr;
}

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

pub fn newString(allocator: std.mem.Allocator, value: []const u8) !*Object {
    const stringPtr = try allocator.create(Object);
    stringPtr.* = Object{
        .StringLiteral = StringLiteral{ .value = value },
    };
    return stringPtr;
}

pub fn newArray(allocator: std.mem.Allocator, elements: std.ArrayList(*Object)) !*Object {
    const arrayPtr = try allocator.create(Object);
    arrayPtr.* = Object{
        .ArrayLiteral = ArrayLiteral{ .elements = elements },
    };
    return arrayPtr;
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

test "test hashLiteral and indexOp" {
    const tests: [7]TestType = [_]TestType{
        .{ .input = "{1:2+4,\"key\":false}", .expected = "{1:6, key:false}" },
        .{ .input = "{1:2+4,\"key\":false}[1]", .expected = "6" },
        .{ .input = "{1:2+4,\"key\":false}[3]", .expected = "null" },
        .{ .input = "let k = 1; {1:2+4,\"key\":false}[k]", .expected = "6" },
        .{ .input = "{}[1]", .expected = "null" },
        .{ .input = "{1:2}[func(x){x}]", .expected = "Error: unusable as hash key: FUNCTION" },
        .{ .input = 
        \\ let two = "two";{ "one": 10 - 9,two: 2,"thr" + "ee": 6 / 2,4: 5,true: 6,false: 7}
        , .expected = "{false:7, one:1, three:3, 4:5, two:2, true:6}" },
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

test "test ArrayLiteral and indexOp" {
    const tests: [8]TestType = [_]TestType{
        .{ .input = "[1,1+1,4-1,false,\"yello\"]", .expected = "[1, 2, 3, false, yello]" },
        .{ .input = "[1,1+1,4-1,false,\"yello\"][1]", .expected = "2" },
        .{ .input = "[1,1+1,4-1,false,\"yello\"][-1]", .expected = "null" },
        .{ .input = "[1,1+1,4-1,false,\"yello\"][100]", .expected = "null" },
        .{ .input = "[1,1+1,4-1,false,\"yello\"][1+3]", .expected = "yello" },
        .{ .input = "let myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];", .expected = "6" },
        .{
            .input = "[1,1+1,4-1,false,\"yello\"][\"x\"]",
            .expected = "Error: evaluated index type expected:INTEGER , got:STRING",
        },
        .{ .input = "1[1]", .expected = "Error: Cannot index on type: INT" },
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

test "test inbuiltFunctions" {
    const tests: [8]TestType = [_]TestType{
        .{ .input = "len(\"1234\")", .expected = "4" },
        .{ .input = "len(\"yello world!\")", .expected = "12" },
        .{
            .input = "len(\"yello\",\"world!\")",
            .expected = "Error: wrong Number Of Arguments. Expected=1, Received=2",
        },
        .{ .input = "len(1234)", .expected = "Error: func::len does not support type: INT" },
        .{ .input = "log(\"testing log func\")", .expected = "null" },
        .{ .input = "let x = [1,2,3]; push(push(x,4),5)", .expected = "[1, 2, 3, 4, 5]" },
        .{ .input = "let x = [1,2,3]; let y = push(x,4); push(y,5)", .expected = "[1, 2, 3, 4, 5]" },
        .{ .input = "push([],1)", .expected = "[1]" },
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

test "test strings" {
    const tests: [4]TestType = [_]TestType{
        .{ .input = "\"hello world\"", .expected = "hello world" },
        .{ .input = "let gh = func(){\"yolo\"}; gh();", .expected = "yolo" },
        .{ .input = "\"yello\" + \"world\"", .expected = "yelloworld" },
        .{ .input = "\"yello\" - \"world\"", .expected = "Error: Unknown Operator: STRING - STRING" },
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

test "test functions and closures" {
    const tests: [6]TestType = [_]TestType{
        .{ .input = "let double = func(x){ x * 2 }; double(10)", .expected = "20" },
        .{ .input = "let triple = func(x){ return x * 3; }; triple(10)", .expected = "30" },
        .{ .input = "let add = func(x,y){ x + y }; add(1+1,3+1)", .expected = "6" },
        .{ .input = "let add = func(x,y){ x + y }; add(1+1,add(10,10))", .expected = "22" },
        .{ .input = "let add = func(x,y){ x + y }; let prod = func(x,y){ x * y }; prod(add(1,1),prod(2,2));", .expected = "8" },
        .{ .input = "let multiplier = func(x){ func(y){x * y}; }; let twoMultiplier = multiplier(2); twoMultiplier(8);", .expected = "16" },
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

test "test counter" {
    const input =
        \\let counter = func(x) {
        \\if (x > 100) {
        \\return true;
        \\} else {
        \\let foobar = 9999;
        \\counter(x + 1);
        \\}
        \\};
        \\counter(0);
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const evalValue = try testEval(&allocator, input);
    var printBuf = String.init(allocator);
    try evalValue.stringValue(&printBuf);
    try std.testing.expect(std.mem.eql(u8, "true", printBuf.str()));
}

test "test fib" {
    const input =
        \\let fibonacci = func(x) {
        \\if (x == 0) {
        \\  return 0;
        \\ } else {
        \\  if (x == 1) {
        \\     return 1;
        \\ } else {
        \\  fibonacci(x - 1) + fibonacci(x - 2);
        \\ }
        \\}
        \\};
        \\fibonacci(15);
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const evalValue = try testEval(&allocator, input);
    var printBuf = String.init(allocator);
    try evalValue.stringValue(&printBuf);
    try std.testing.expect(std.mem.eql(u8, "610", printBuf.str()));
}
