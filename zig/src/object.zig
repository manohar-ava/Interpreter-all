const std = @import("std");
const Parser = @import("./parser.zig");
const Lexer = @import("./lexer.zig");
const ast = @import("./abstract_syntax_tree.zig");
const evaluator = @import("evaluator.zig");
const testing = std.testing;

pub const Object = union(enum) {
    Interger: *const Interger,
    Boolean: *const Boolean,
    Null: *const Null,
    pub fn format(self: Object, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            inline else => |item| try writer.print("{}", .{item}),
        }
    }
};

pub fn isIntergerTag(ob: Object) bool {
    return @as(std.meta.Tag(Object), ob) == @as(std.meta.Tag(Object), Object{ .Interger = undefined });
}

pub fn isTruthy(ob: Object) bool {
    return switch (ob) {
        .Boolean => |item| item.value,
        .Null => false,
        else => true,
    };
}

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
        const lex = try Lexer.newLexer(&allocator, input);
        defer allocator.destroy(lex);
        var parser = try Parser.newParser(&allocator, lex);
        const program = try parser.parse();
        const evalValue = try evaluator.evaluate(&allocator, program);
        std.debug.print("{any}\n", .{evalValue});
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
        const lex = try Lexer.newLexer(&allocator, input);
        defer allocator.destroy(lex);
        var parser = try Parser.newParser(&allocator, lex);
        const program = try parser.parse();
        const evalValue = try evaluator.evaluate(&allocator, program);
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
        const lex = try Lexer.newLexer(&allocator, input);
        defer allocator.destroy(lex);
        var parser = try Parser.newParser(&allocator, lex);
        const program = try parser.parse();
        const evalValue = try evaluator.evaluate(&allocator, program);
        const boolValue = switch (evalValue.?) {
            .Boolean => |item| item.value,
            else => @panic("boolean test failed"),
        };
        try std.testing.expect(boolValue == expected[i]);
        std.debug.print("--------------------------------------------- \n", .{});
    }
    std.debug.print("============================================= \n", .{});
}
