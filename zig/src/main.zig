const std = @import("std");
const lexer = @import("./lexer.zig");
const Parser = @import("./parser.zig");
const evaluator = @import("evaluator.zig");
const environment = @import("environment.zig");
const String = @import("string.zig").String;

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var env = environment.Environment.new(allocator);
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        try stdout.print("[ REPL System v0.0.1 Initialized ]\nWelcome Champ. Your coding adventure begins here... ⚡\n", .{});
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
            }
        }
    } else {
        try stdout.print("The deed is done, Champ. What shall be your next trial?\n", .{});
        const filename = args[1];
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        // Get the file size
        const file_size = try file.getEndPos();
        // Read the entire file content
        const content = try file.reader().readAllAlloc(allocator, file_size);
        defer allocator.free(content);
        const lex = try lexer.newLexer(&allocator, content);
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
                    defer objPrintBuf.deinit();
                    try evalValue.stringValue(&objPrintBuf);
                    try stdout.print(">>{s}\n", .{objPrintBuf.str()});
                },
            }
        }
    }

    // store input strings
}
