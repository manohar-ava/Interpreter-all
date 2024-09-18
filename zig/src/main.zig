const std = @import("std");
const lexer = @import("./lexer.zig");
const Parser = @import("./parser.zig");
const evaluator = @import("evaluator.zig");
const environment = @import("environment.zig");
const String = @import("string.zig").String;

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("let's start parsing\n", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var env = environment.Environment.new(allocator);
    // store input strings
    var inputBuf: [65536]u8 = undefined;
    var lastPos: usize = 0;
    while (true) {
        try stdout.print(">> ", .{});
        if (try stdin.readUntilDelimiterOrEof(inputBuf[lastPos..], '\n')) |input| {
            lastPos += input.len;
            const lex = try lexer.newLexer(&allocator, input);
            var parser = try Parser.newParser(&allocator, lex);
            const program = try parser.parse();
            const hasErrors = parser.printErrors();
            if (!hasErrors) {
                const evalValue = try evaluator.evaluate(allocator, program, &env);
                switch (evalValue.*) {
                    .Error => |item| {
                        try stdout.print("Error: {s}\n", .{item.value});
                    },
                    else => {
                        var objPrintBuf = String.init(allocator);
                        try evalValue.stringValue(&objPrintBuf);
                        try stdout.print("{s}\n", .{objPrintBuf.str()});
                    },
                }
            }
        } else {
            break;
        }
    }
}
