const std = @import("std");
const lexer = @import("./lexer.zig");
const Parser = @import("./parser.zig");
const evaluator = @import("evaluator.zig");
const ast = @import("abstract_syntax_tree.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    const stdin_file = std.io.getStdIn().reader();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    // try stdout.print(
    //     \\ ╔════════════════════════════════════════════════════════════════════════════════════╗
    //     \\ ║ ▀█████████▄  ▄██   ▄       ███        ▄████████         ▄▄▄▄███▄▄▄▄      ▄████████ ║
    //     \\ ║   ███    ███ ███   ██▄ ▀█████████▄   ███    ███       ▄██▀▀▀███▀▀▀██▄   ███    ███ ║
    //     \\ ║   ███    ███ ███▄▄▄███    ▀███▀▀██   ███    █▀        ███   ███   ███   ███    █▀  ║
    //     \\ ║  ▄███▄▄▄██▀  ▀▀▀▀▀▀███     ███   ▀  ▄███▄▄▄           ███   ███   ███  ▄███▄▄▄     ║
    //     \\ ║ ▀▀███▀▀▀██▄  ▄██   ███     ███     ▀▀███▀▀▀           ███   ███   ███ ▀▀███▀▀▀     ║
    //     \\ ║   ███    ██▄ ███   ███     ███       ███    █▄        ███   ███   ███   ███    █▄  ║
    //     \\ ║   ███    ███ ███   ███     ███       ███    ███       ███   ███   ███   ███    ███ ║
    //     \\ ║ ▄█████████▀   ▀█████▀     ▄████▀     ██████████        ▀█   ███   █▀    ██████████ ║
    //     \\ ╚════════════════════════════════════════════════════════════════════════════════════╝
    // , .{});
    try stdout.print("let's start parsing", .{});
    try bw.flush();
    try stdout.print("\n>>", .{});
    try bw.flush();
    var buffer: [512]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    while (try stdin_file.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const lex = try lexer.newLexer(&allocator, line);
        defer allocator.destroy(lex);
        var parser = try Parser.newParser(&allocator, lex);
        const program = try parser.parse();
        const hasErrors = parser.printErrors();
        if (!hasErrors) {
            const evalValue = try evaluator.evaluate(&allocator, program);
            try stdout.print("{}\n", .{evalValue});
        }
        try stdout.print(">>", .{});
        try bw.flush();
    }
}
