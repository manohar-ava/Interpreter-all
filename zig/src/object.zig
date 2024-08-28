const std = @import("std");
const Parser = @import("./parser.zig");
const Lexer = @import("./lexer.zig");
const ast = @import("./abstract_syntax_tree.zig");
const evaluator = @import("evaluator.zig");
const testing = std.testing;

pub const Object = union(enum) {
    Interger: Interger,
    Boolean: Boolean,
    Null: Null,
    // pub fn format(self: Object, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    //     switch (self) {
    //         inline else => |item| try writer.print("{}", .{item}),
    //     }
    // }
};

pub const Interger = struct {
    value: i64,
    // pub fn format(self: Interger, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    //     try writer.print("{}", .{self.value});
    // }
};
pub const Boolean = struct {
    value: bool,
    pub fn format(self: Boolean, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{}", .{self.value});
    }
};

pub const Null = struct {
    pub fn format(_: Null, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("null");
    }
};

test "test int evaluation" {
    const input =
        \\10;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try Lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try Parser.newParser(&allocator, lex);
    const program = try parser.parse();
    const eval = try evaluator.newEval(&allocator);
    const evalValue: Object = eval.evaluate(ast.Statement{ .Program = program.* });
    const intValue = switch (evalValue) {
        .Interger => |item| item.value,
        else => 0,
    };
    try std.testing.expect(intValue == 10);
}
